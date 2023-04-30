// pinentry-touchid - A barebones pinentry for macOS using Touch ID and Keychain.
// Author: Matt Coneybeare <matt@coneybeare.me>
// SPDX-License-Identifier: ISC

import Foundation
import LocalAuthentication
import Darwin.C

let keychainServiceName = "me.coneybeare.matt.pinentry-touchid.password"
let policy = LAPolicy.deviceOwnerAuthentication
let reason = "commit"
let logDirectory = NSTemporaryDirectory()
let logFileName = "touchid-pinenty.log"

extension String {
    func appendLine(to url: URL) throws {
        try self.appending("\n").append(to: url)
    }
    func append(to url: URL) throws {
        let data = self.data(using: String.Encoding.utf8)
        try data?.append(to: url)
    }
}
extension Data {
    func append(to url: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(self)
        } else {
            try write(to: url)
        }
    }
}

// Logging
var logFile: URL = NSURL() as URL
if let fileURL = NSURL.fileURL(withPathComponents: [logDirectory, logFileName]) {
    logFile = fileURL
}

try? "--------------------------------------------".appendLine(to: logFile)
try? "- Starting up at \(Date()) -".appendLine(to: logFile)
try? "--------------------------------------------".appendLine(to: logFile)

// Save the passphrase into Keychain.
func setPassword(password: String) -> Bool  {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainServiceName,
        kSecValueData as String: password.data(using: .utf8)!
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    return status == errSecSuccess
}

// Get the passphrase from Keychain.
func getPassword() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: keychainServiceName,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: true
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    if status == errSecSuccess {
        guard let passwordData = item as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8) else {
                return nil
        }
        return password
    } else {
        item.map(Unmanaged.passUnretained)?.release()
        return nil
    }
}

func logAndPrint(_ printPrefix: String, _ logMessage: String) {
    try? logMessage.appendLine(to: logFile)
    print("\(printPrefix) \(logMessage)")
}

func getErrorDescription(errorCode: Int) -> String {

    switch errorCode {

    case LAError.authenticationFailed.rawValue:
        return "Authentication was not successful, because user failed to provide valid credentials."

    case LAError.appCancel.rawValue:
        return "Authentication was canceled by application (e.g. invalidate was called while authentication was in progress)."

    case LAError.invalidContext.rawValue:
        return "LAContext passed to this call has been previously invalidated."

    case LAError.notInteractive.rawValue:
        return "Authentication failed, because it would require showing UI which has been forbidden by using interactionNotAllowed property."

    case LAError.passcodeNotSet.rawValue:
        return "Authentication could not start, because passcode is not set on the device."

    case LAError.systemCancel.rawValue:
        return "Authentication was canceled by system (e.g. another application went to foreground)."

    case LAError.userCancel.rawValue:
        return "Authentication was canceled by user (e.g. tapped Cancel button)."

    case LAError.userFallback.rawValue:
        return "Authentication was canceled, because the user tapped the fallback button (Enter Password)."

    default:
        return "Error code \(errorCode) not found"
    }

 }

func interact() {
    let context = LAContext()
    context.touchIDAuthenticationAllowableReuseDuration = 0

    var authorizationError: NSError?
    guard context.canEvaluatePolicy(policy, error: &authorizationError) else {
        logAndPrint("ERR", "Failed to check policy: \(authorizationError?.localizedDescription ?? "Unknown")")
        exit(EXIT_FAILURE)
    }

    print("OK hello")
    while let input = readLine() {
        if input.lowercased().hasPrefix("setpass") {
            guard setPassword(password: "CHANGEMENOW") else {
                logAndPrint("ERR", "Failed to write the default password.")
                continue
            }
            logAndPrint("OK", "Password set to default value 'CHANGEMENOW'. Change it using Keychain Access ASAP.")
            continue
        }

        switch input.lowercased() {
            case "getpin":
                context.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: reason) { success, evaluationError in
                    if success {
                        guard let password = getPassword() else {
                            logAndPrint("ERR", "Failed to get password from keychain.")
                            return
                        }
                        print("D \(password)")
                        print("OK thanks.")
                    } else if let errorObj = evaluationError {
                        logAndPrint("ERR", getErrorDescription(errorCode: errorObj._code))
                    } else {
                        logAndPrint("ERR", "Unknown error")
                    }
                }
            case "bye":
                logAndPrint("OK", "Goodbye.")
                try? "--------------------------------------------".appendLine(to: logFile)
                try? "- Exiting GPG at \(Date()) -".appendLine(to: logFile)
                try? "--------------------------------------------".appendLine(to: logFile)
                try? "\n".appendLine(to: logFile)
                exit(EXIT_SUCCESS)
            default:
                logAndPrint("OK", "Command not recognized '\(input)'.")
        }
    }
    // on EOF, continue running until ^C
    dispatchMain()
}

setbuf(__stdoutp, nil)
interact()
