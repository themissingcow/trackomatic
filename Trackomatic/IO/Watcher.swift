
import Foundation

@objc public class Watcher : NSObject
{
    public typealias Callback = ( _ watcher: Watcher, _ event: DispatchSource.FileSystemEvent ) -> Void;

    public convenience init( url: URL, callback: @escaping Callback )
    {
        self.init();
        watch( path: url.path, callback: callback );
    }
    
    deinit
    {
        stop();
    }

    private var fileDescriptor : Int32 = -1 {
        didSet {
            if oldValue != -1 {
                close( oldValue )
            }
        }
    }
    
    private var dispatchSource : DispatchSourceFileSystemObject?

    @discardableResult
    public func watch( path: String, callback: @escaping Callback ) -> Bool
    {
        fileDescriptor = open( path, O_EVTONLY );
        
        if fileDescriptor < 0 { return false }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor, eventMask: .all,
            queue: DispatchQueue.main
        );
                
        source.setEventHandler {
            callback( self, source.data );
        }
        
        source.setCancelHandler {
            self.fileDescriptor = -1;
        }
        
        source.activate();
        dispatchSource = source;

        return true
    }

    @objc public func stop() {

        guard let source = dispatchSource else {
            return
        }

        source.setEventHandler( handler: nil );
        source.cancel();
        dispatchSource = nil;
    }
}
