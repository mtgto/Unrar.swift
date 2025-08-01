// SPDX-FileCopyrightText: 2021 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: MIT

import Cunrar
import Foundation

/// Defines the various error codes that the listing and extraction methods return
public enum UnrarError: Error, LocalizedError, CustomStringConvertible {
    /// The last file of the archive has been read
    case endOfArchive
    
    /// The library ran out of memory while reading the archive
    case noMemory
    
    /// The header's CRC doesn't match the decompressed data's CRC
    case badData
    
    /// The archive is not a valid RAR file
    case badArchive
    
    /// The archive is an unsupported RAR format or version
    case unknownFormat
    
    /// Failed to open a reference to the file
    case eopen
    
    /// Failed to create the target directory for extraction
    case ecreate
    
    /// Failed to close the archive
    case eclose
    
    /// Failed to read the archive
    case eread
    
    /// Failed to write a file to disk
    case ewrite
    
    /// The archive header's comments are larger than the buffer size
    case smallBuffer
    
    /// The cause of the error is unspecified
    case unknown
    
    /// A password was not given for a password-protected archive
    case missingPassword
    
    /// Reference error
    case ereference
    
    /// The given password was incorrect
    case badPassword
    
    /// No data was returned from the archive
    case archiveNotFound
    
    /// User cancelled the operation
    case userCancelled
    
    /// Error converting string to UTF-8
    case stringConversion
    
    /// CRC32 check failed
    case crcNotMatch
    
    /// Extraction to memory requires too much memory
    case tooLargeMemory
    /// max password limit is 512
    case passwordOverLimit
    
    /// Creates an `UnrarError` from a given integer error code.
    /// - Parameter errorCode: The integer error code returned by the UnRAR library.
    /// - Returns: The corresponding `UnrarError` enum case.
    public static func fromErrorCode(_ errorCode: Int32) -> UnrarError {
        switch errorCode {
            case ERAR_END_ARCHIVE:
                return .endOfArchive
            case ERAR_NO_MEMORY:
                return .noMemory
            case ERAR_BAD_DATA:
                return .badData
            case ERAR_BAD_ARCHIVE:
                return .badArchive
            case ERAR_UNKNOWN_FORMAT:
                return .unknownFormat
            case ERAR_EOPEN:
                return .eopen
            case ERAR_ECREATE:
                return .ecreate
            case ERAR_ECLOSE:
                return .eclose
            case ERAR_EREAD:
                return .eread
            case ERAR_EWRITE:
                return .ewrite
            case ERAR_SMALL_BUF:
                return .smallBuffer
            case ERAR_UNKNOWN:
                return .unknown
            case ERAR_MISSING_PASSWORD:
                return .missingPassword
            case ERAR_EREFERENCE:
                return .ereference
            case ERAR_BAD_PASSWORD:
                return .badPassword
            default:
                return .unknown
        }
    }
    
    /// Provides a localized description for each error case.
    public var errorDescription: String? {
        switch self {
            case .endOfArchive:
                return "The last file of the archive has been read"
            case .noMemory:
                return "Ran out of memory while reading archive"
            case .badData:
                return "Archive has a corrupt header"
            case .badArchive:
                return "File is not a valid RAR archive"
            case .unknownFormat:
                return "RAR headers encrypted in unknown format"
            case .eopen:
                return "Failed to open a reference to the file"
            case .ecreate:
                return "Failed to create the target directory for extraction"
            case .eclose:
                return "Error encountered while closing the archive"
            case .eread:
                return "Error encountered while reading the archive"
            case .ewrite:
                return "Error encountered while writing a file to disk"
            case .smallBuffer:
                return "Buffer too small to contain entire comments"
            case .unknown:
                return "An unknown error occurred"
            case .missingPassword:
                return "No password given to unlock a protected archive"
            case .ereference:
                return "Reference error"
            case .badPassword:
                return "Provided password is incorrect"
            case .archiveNotFound:
                return "Unable to find the archive"
            case .userCancelled:
                return "User cancelled the operation in progress"
            case .stringConversion:
                return "Error converting a string to UTF-8"
            case .crcNotMatch:
                return "CRC32 check not pass"
            case .tooLargeMemory:
                return "Extraction to memory requires too much memory (>100M)"
            case .passwordOverLimit:
                return  "max password limit is 128"
        }
    }
    
    /// Provides a custom string description for the error, defaulting to "Unknown error" if no specific description is available.
    public var description: String {
        return errorDescription ?? "Unknown error"
    }
}
