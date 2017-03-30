import Foundation
import minizip


public enum UnzipError: Error {
    case fileNotFound
    case fail
}

public class SwiftZip {
    
    /**
     Set of vaild file extensions
     */
    internal static var customFileExtensions: Set<String> = []
    public class func unzipFile(_ zipFilePath: URL, destination: URL, overwrite: Bool, password: String?) throws {
        
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let path = zipFilePath.path
        
        if fileManager.fileExists(atPath: path) == false || fileExtensionIsInvalid(zipFilePath.pathExtension) {
            throw UnzipError.fileNotFound
        }
        
        // Unzip set up
        var ret: Int32 = 0
        var crc_ret: Int32 = 0
        let bufferSize: UInt32 = 4096
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bufferSize))
        
        // Progress handler set up
        var totalSize: Double = 0.0
        var currentPosition: Double = 0.0
        let fileAttributes = try fileManager.attributesOfItem(atPath: path)
        if let attributeFileSize = fileAttributes[FileAttributeKey.size] as? Double {
            totalSize += attributeFileSize
        }
        
        
        // Begin unzipping
        let zip = unzOpen64(path)
        defer {
            unzClose(zip)
        }
        if unzGoToFirstFile(zip) != UNZ_OK {
            throw UnzipError.fail
        }
        repeat {
            if let cPassword = password?.cString(using: String.Encoding.ascii) {
                ret = unzOpenCurrentFilePassword(zip, cPassword)
            }
            else {
                ret = unzOpenCurrentFile(zip);
            }
            if ret != UNZ_OK {
                throw UnzipError.fail
            }
            var fileInfo = unz_file_info64()
            memset(&fileInfo, 0, MemoryLayout<unz_file_info>.size)
            ret = unzGetCurrentFileInfo64(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            if ret != UNZ_OK {
                unzCloseCurrentFile(zip)
                throw UnzipError.fail
            }
            currentPosition += Double(fileInfo.compressed_size)
            let fileNameSize = Int(fileInfo.size_filename) + 1
            //let fileName = UnsafeMutablePointer<CChar>(allocatingCapacity: fileNameSize)
            let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: fileNameSize)
            
            unzGetCurrentFileInfo64(zip, &fileInfo, fileName, UInt(fileNameSize), nil, 0, nil, 0)
            fileName[Int(fileInfo.size_filename)] = 0
            
            var pathString = String(cString: fileName)
            
            guard pathString.characters.count > 0 else {
                throw UnzipError.fail
            }
            
            var isDirectory = false
            let fileInfoSizeFileName = Int(fileInfo.size_filename-1)
            if (fileName[fileInfoSizeFileName] == "/".cString(using: String.Encoding.utf8)?.first || fileName[fileInfoSizeFileName] == "\\".cString(using: String.Encoding.utf8)?.first) {
                isDirectory = true;
            }
            free(fileName)
            if pathString.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) != nil {
                pathString = pathString.replacingOccurrences(of: "\\", with: "/")
            }
            
            let fullPath = destination.appendingPathComponent(pathString).path
            
            let creationDate = Date()
            let directoryAttributes = [FileAttributeKey.creationDate.rawValue : creationDate,
                                       FileAttributeKey.modificationDate.rawValue : creationDate]
            do {
                if isDirectory {
                    try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
                else {
                    let parentDirectory = (fullPath as NSString).deletingLastPathComponent
                    try fileManager.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
            } catch {}
            if fileManager.fileExists(atPath: fullPath) && !isDirectory && !overwrite {
                unzCloseCurrentFile(zip)
                ret = unzGoToNextFile(zip)
            }
            var filePointer: UnsafeMutablePointer<FILE>?
            filePointer = fopen(fullPath, "wb")
            while filePointer != nil {
                let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                if readBytes > 0 {
                    fwrite(buffer, Int(readBytes), 1, filePointer)
                }
                else {
                    break
                }
            }
            
            fclose(filePointer)
            crc_ret = unzCloseCurrentFile(zip)
            if crc_ret == UNZ_CRCERROR {
                throw UnzipError.fail
            }
            
            //Set file permissions from current fileInfo
            if fileInfo.external_fa != 0 {
                let permissions = (fileInfo.external_fa >> 16) & 0x1FF
                //We will devifne a valid permission range between Owner read only to full access
                if permissions >= 0o400 && permissions <= 0o777 {
                    do {
                        try fileManager.setAttributes([.posixPermissions : permissions], ofItemAtPath: fullPath)
                    } catch {
                        print("Failed to set permissions to file \(fullPath), error: \(error)")
                    }
                }
            }
            
            ret = unzGoToNextFile(zip)
            
            
        } while (ret == UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
        
        
    }
    /**
     Check if file extension is invalid.
     
     - parameter fileExtension: A file extension.
     
     - returns: false if the extension is a valid file extension, otherwise true.
     */
    internal class func fileExtensionIsInvalid(_ fileExtension: String?) -> Bool {
        
        guard let fileExtension = fileExtension else { return true }
        
        return !isValidFileExtension(fileExtension)
    }
    
    /**
     Add a file extension to the set of custom file extensions
     
     - parameter fileExtension: A file extension.
     */
    public class func addCustomFileExtension(_ fileExtension: String) {
        customFileExtensions.insert(fileExtension)
    }
    
    /**
     Remove a file extension from the set of custom file extensions
     
     - parameter fileExtension: A file extension.
     */
    public class func removeCustomFileExtension(_ fileExtension: String) {
        customFileExtensions.remove(fileExtension)
    }
    
    /**
     Check if a specific file extension is valid
     
     - parameter fileExtension: A file extension.
     
     - returns: true if the extension valid, otherwise false.
     */
    public class func isValidFileExtension(_ fileExtension: String) -> Bool {
        
        let validFileExtensions: Set<String> = customFileExtensions.union(["zip", "cbz"])
        
        return validFileExtensions.contains(fileExtension)
    }
}
