//
//  AppConfigurationClient.swift
//  DemoAppObjC
//
//  Created by Travis Prescott on 8/8/19.
//  Copyright © 2019 Travis Prescott. All rights reserved.
//

import Foundation

@objc
class AppConfigurationClient: NSObject {

    @objc public static let shared = AppConfigurationClient()
    private static let apiVersion = "2019-01-01"

    lazy var session = URLSession(configuration: .default)
    
    private var isConfigured = false
    private var path: String = ""
    private var endpoint: URL!
    private var credential: AppConfigurationClientCredentials?
    
    override private init() {
        super.init()
    }
    
    @objc func configure(withConnectionString connectionString: String) throws {
        self.credential = try AppConfigurationClientCredentials.init(withConnectionString: connectionString)
        self.endpoint = self.credential!.credentials.baseUri!
        self.isConfigured = true
    }
    
    @objc func getConfigurationSettings(forKey key: String?, forLabel label: String?, completion: @escaping ([ConfigurationSetting]?) -> Void) {
        guard self.isConfigured else { return }
        guard let endpoint = self.endpoint else { return }

        let baseUrl = "\(endpoint)/kv"
        let queryStringParams = [
            "key": key ?? "*",
            "label": label ?? "*",
            "fields": ""
        ]
        let method = "GET"
        var urlComponent = URLComponents(string: baseUrl)!
        urlComponent.queryItems = queryStringParams.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        let headers = self.credential!.getAuthorizationheaders(url: urlComponent.url!, httpMethod: method, contents: nil)
        var request = URLRequest(url: urlComponent.url!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        
        // Make network call
        self.session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                NSLog("Error: \(error.localizedDescription)")
                completion(nil)
            } else if let data = data, let httpResponse = response as? HTTPURLResponse {
                let decoder = JSONDecoder()
                do {
                    let settings = try decoder.decode(ConfigurationSettingsResponse.self, from: data)
                    completion(settings.items)
                } catch {
                    NSLog("Unexpected error: \(error).")
                    completion(nil)
                }
            }
        }.resume()
    }
    
    @objc func set(parameters: ConfigurationSettingPutParameters, forKey key: String, forLabel label: String?, completion: (() -> Void)?) {
        guard self.isConfigured else { return }
        guard let endpoint = self.endpoint else { return }
        
        let baseUrl = "\(endpoint)/kv/\(key)"
        let queryStringParams = [
            "label": label ?? "*"
        ]
        let method = "PUT"
        var urlComponent = URLComponents(string: baseUrl)!
        urlComponent.queryItems = queryStringParams.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try! encoder.encode(parameters)
        var headers = self.credential!.getAuthorizationheaders(url: urlComponent.url!, httpMethod: method, contents: body)
        headers["Content-Type"] = "application/vnd.microsoft.appconfig.kv+json;"
        var request = URLRequest(url: urlComponent.url!)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body

        // Make network call
        self.session.dataTask(with: request) { (data, response, error) in
            if let error = error {
                NSLog("Error: \(error.localizedDescription)")
                completion?()
            } else if let data = data, let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    NSLog("Failed with status code \(httpResponse.statusCode)")
                }
                completion?()
            }
        }.resume()
    }
}
