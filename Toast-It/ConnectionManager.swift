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
    var onPeerChanged: (([MCPeerID]) -> Void)?
    var onDataReceived: ((Data) -> Void)?
    var onConnected: (() -> Void)?
    var hostSeatingOrder: [String] = []
    
    // name of peer who sent most recent message
    private(set) var lastSenderName: String?
    
    private let serviceType = "toast-it"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    var session: MCSession
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    var targetCode: String = ""
    
    override init() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }
    
    // lobby
    func hostLobby(with code: String) {
        let discoveryInfo = ["lobbyCode": code]
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        isHost = true
    }
    
    
    func joinLobby(with code: String) {
        targetCode = code
        isHost = false
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func reset() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        isHost = false
        targetCode = ""
        hostSeatingOrder = []
        lastSenderName = nil
        onPeerChanged = nil
        onDataReceived = nil
        onConnected = nil
    }
    
    // convenience send
    func send(action: GameAction, toPeers peers: [MCPeerID]? = nil) {
        guard let data = try? JSONEncoder().encode(action) else { return }
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }
        try? session.send(data, toPeers: targets, with: .reliable)
    }
    
    // MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            if state == .connected && !self.isHost {
                self.onConnected?()
            }
            self.onPeerChanged?(session.connectedPeers)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        lastSenderName = peerID.displayName
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
        
        if let hostCode = info?["lobbyCode"], hostCode == self.targetCode {
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
            browser.stopBrowsingForPeers()
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
    
}
