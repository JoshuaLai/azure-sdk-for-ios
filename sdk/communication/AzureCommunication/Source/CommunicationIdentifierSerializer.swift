// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------

#if canImport(AzureCore)
    import AzureCore
#endif
import Foundation

public class CommunicationIdentifierSerializer {
    static func deserialize(identifier: CommunicationIdentifierModel) throws -> CommunicationIdentifier {
        guard let rawId = identifier.rawId else {
            throw AzureError.client("Can't serialize CommunicationIdentifierModel: rawId is undefined.")
        }

        try assertOneNestedModel(identifier)

        if let communicationUser = identifier.communicationUser {
            return CommunicationUserIdentifier(identifier: communicationUser.id)
        } else if let phoneNumber = identifier.phoneNumber {
            return PhoneNumberIdentifier(phoneNumber: phoneNumber.value, rawId: rawId)
        } else if let microsoftTeamsUser = identifier.microsoftTeamsUser {
            guard let isAnonymous = microsoftTeamsUser.isAnonymous else {
                throw AzureError.client("Can't serialize CommunicationIdentifierModel: isAnonymous is undefined.")
            }

            guard let cloud = microsoftTeamsUser.cloud else {
                throw AzureError.client("Can't serialize CommunicationIdentifierModel: cloud is undefined.")
            }

            return MicrosoftTeamsUserIdentifier(
                userId: microsoftTeamsUser.userId,
                isAnonymous: isAnonymous,
                rawId: rawId,
                cloudEnvironment: try deserialize(model: cloud)
            )
        }

        return UnknownIdentifier(identifier: rawId)
    }

    private static func deserialize(model: CommunicationCloudEnvironmentModel) throws -> CommunicationCloudEnvironment {
        if model == CommunicationCloudEnvironmentModel.Public {
            return CommunicationCloudEnvironment.Public
        }
        if model == CommunicationCloudEnvironmentModel.Gcch {
            return CommunicationCloudEnvironment.Gcch
        }
        if model == CommunicationCloudEnvironmentModel.Dod {
            return CommunicationCloudEnvironment.Dod
        }

        return CommunicationCloudEnvironment(environmentValue: model.requestString)
    }

    static func assertOneNestedModel(_ identifier: CommunicationIdentifierModel) throws {
        var presentProperties = [String]()

        if let _ = identifier.communicationUser {
            presentProperties.append("communicationUser")
        }
        if let _ = identifier.phoneNumber {
            presentProperties.append("phoneNumber")
        }
        if let _ = identifier.microsoftTeamsUser {
            presentProperties.append("microsoftTeamsUser")
        }

        if presentProperties.count > 1 {
            throw AzureError.client("Only one property should be present")
        }
    }

    static func serialize(identifier: CommunicationIdentifier) throws -> CommunicationIdentifierModel {
        switch identifier {
        case let user as CommunicationUserIdentifier:
            return CommunicationIdentifierModel(
                rawId: nil,
                communicationUser: CommunicationUserIdentifierModel(
                    id: user
                        .identifier
                ),
                phoneNumber: nil,
                microsoftTeamsUser: nil
            )
        case let phoneNumber as PhoneNumberIdentifier:
            return CommunicationIdentifierModel(
                rawId: phoneNumber.rawId,
                communicationUser: nil,
                phoneNumber: PhoneNumberIdentifierModel(value: phoneNumber.phoneNumber),
                microsoftTeamsUser: nil
            )
        case let teamsUser as MicrosoftTeamsUserIdentifier:
            return try CommunicationIdentifierModel(
                rawId: teamsUser.rawId,
                communicationUser: nil,
                phoneNumber: nil,
                microsoftTeamsUser:
                MicrosoftTeamsUserIdentifierModel(
                    userId: teamsUser.userId,
                    isAnonymous: teamsUser
                        .isAnonymous,
                    cloud: serialize(
                        cloud: teamsUser
                            .cloudEnviroment
                    )
                )
            )
        case let unknown as UnknownIdentifier:
            return CommunicationIdentifierModel(
                rawId: unknown.identifier,
                communicationUser: nil,
                phoneNumber: nil,
                microsoftTeamsUser: nil
            )
        default:
            throw AzureError.client("Not support kind in CommunicationIdentifier.")
        }
    }

    private static func serialize(cloud: CommunicationCloudEnvironment) throws -> CommunicationCloudEnvironmentModel {
        if cloud == CommunicationCloudEnvironment.Public {
            return CommunicationCloudEnvironmentModel.Public
        }
        if cloud == CommunicationCloudEnvironment.Gcch {
            return CommunicationCloudEnvironmentModel.Gcch
        }
        if cloud == CommunicationCloudEnvironment.Dod {
            return CommunicationCloudEnvironmentModel.Dod
        }

        return CommunicationCloudEnvironmentModel(cloud.environmentValue)
    }
}
