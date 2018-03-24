//
//  CodableResource.swift
//  AzureData
//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// Represents a resource type in the Azure Cosmos DB service.
/// All Azure Cosmos DB resources, such as `Database`, `DocumentCollection`, and `Document` implement this protocal.
public protocol CodableResource : Codable {
    
    static var type:String  { get }
    static var list:String  { get }
    
    /// Gets or sets the Id of the resource in the Azure Cosmos DB service.
    var id: String  { get }
    
    /// Gets or sets the Resource Id associated with the resource in the Azure Cosmos DB service.
    var resourceId: String  { get }
    
    /// Gets the self-link associated with the resource from the Azure Cosmos DB service.
    var selfLink: String? { get }
    
    /// Gets the entity tag associated with the resource from the Azure Cosmos DB service.
    var etag: String? { get }
    
    /// Gets the last modified timestamp associated with the resource from the Azure Cosmos DB service.
    var timestamp: Date?   { get }
    
    /// Gets the alt-link associated with the resource from the Azure Cosmos DB service.
    var altLink: String? { get }
    
    mutating func setAltLink(to link: String)
}

extension CodableResource {
    public mutating func setAltLink(withContentPath path: String?) {
        let pathComponent = path.isNilOrEmpty ? Self.type : "\(path!)/\(Self.type)"
        self.setAltLink(to: "\(pathComponent)/\(id)")
    }
}
