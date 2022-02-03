//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AWSPluginsCore
import Foundation

struct ConfigureFetchIdentity: Action {

    let identifier = "ConfigureFetchIdentity"
    
    let cognitoSession: AWSAuthCognitoSession

    func execute(withDispatcher dispatcher: EventDispatcher,
                 environment: Environment)
    {
        
        switch cognitoSession.cognitoTokensResult {
        case .success: break;
        case .failure(let authError):
            guard case .signedOut = authError else {
                
                let authZError = AuthorizationError.service(error:authError)
                let event = FetchIdentityEvent(eventType: .throwError(authZError))
                dispatcher.send(event)
                
                let updateCognitoSession = cognitoSession.copySessionByUpdating(
                    identityIdResult: .failure(authError))
                // Move to fetching the AWS Credentials
                let fetchAwsCredentialsEvent = FetchAuthSessionEvent(
                    eventType: .fetchAWSCredentials(updateCognitoSession))
                dispatcher.send(fetchAwsCredentialsEvent)
                return
            }
            break
        }
        
        let timer = LoggingTimer(identifier).start("### Starting execution")
        
        let fetchIdentity: FetchIdentityEvent
        
        // If identity already exists return that.
        if case .success = cognitoSession.identityIdResult {
            fetchIdentity = FetchIdentityEvent(eventType: .fetched)
            timer.note("### sending event \(fetchIdentity.type)")
            dispatcher.send(fetchIdentity)
            
            // Move to fetching the AWS Credentials
            let fetchAwsCredentialsEvent = FetchAuthSessionEvent(
                eventType: .fetchAWSCredentials(cognitoSession))
            timer.stop("### sending event \(fetchAwsCredentialsEvent.type)")
            dispatcher.send(fetchAwsCredentialsEvent)
        } else {
            fetchIdentity = FetchIdentityEvent(eventType: .fetch(cognitoSession))
            timer.stop("### sending event \(fetchIdentity.type)")
            dispatcher.send(fetchIdentity)
        }
    }
}

extension ConfigureFetchIdentity: DefaultLogger { }

extension ConfigureFetchIdentity: CustomDebugDictionaryConvertible {
    var debugDictionary: [String: Any] {
        [
            "identifier": identifier
        ]
    }
}

extension ConfigureFetchIdentity: CustomDebugStringConvertible {
    var debugDescription: String {
        debugDictionary.debugDescription
    }
}