//
//  ConnectionManager.swift
//  Toast-It
//
//  Created by Christien on 4/2/26.
//

import MultipeerConnectivity

class ConnectionManager: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
    static let shared = ConnectionManager()
    
    var isHost = false
    
    private let serviceType = "toast-it"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    var session: MCSession
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    
   
    var onDataReceived: ((Data) -> Void)?
    var onConnected: (() -> Void)?

    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    
    func hostLobby(with code: String) {
        isHost = true
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["lobbyCode": code], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

   
    func joinLobby(with code: String) {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
      
        browser?.startBrowsingForPeers()
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected {
            DispatchQueue.main.async { self.onConnected?() }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.onDataReceived?(data) }
    }
    
        func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
        }
        
        func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
           
        }
        
        func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
           
        }

     
        func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
           
            invitationHandler(true, self.session)
        }


        func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
         
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }

        func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
            
        }
    

}
