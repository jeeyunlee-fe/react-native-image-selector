//
//  ImageShowerViewController.swift
//  ImageSelector
//
//  Created by Dongho Choi on 2020/11/04.
//  Copyright © 2020 Facebook. All rights reserved.
//

import UIKit
import Photos

class ImageShowerViewController: UIViewController {
    public var fetchedAssets: PHFetchResult<PHAsset>?
    public lazy var collectionView: UICollectionView = {
        self.layout.scrollDirection = .vertical
        let cv = UICollectionView(frame: .zero, collectionViewLayout: self.layout)
        cv.register(ImageShowerCell.self, forCellWithReuseIdentifier: self.reusableIdentifier)
        cv.backgroundColor = .white
        cv.delegate = self
        cv.dataSource = self
        return cv
    }()
    private var globalCallback: RCTResponseSenderBlock?
    private let layout = UICollectionViewFlowLayout()
    private let reusableIdentifier: String = "cell"
    private var options: [String: Any] = [:]
    
    init(fetchedAssets: PHFetchResult<PHAsset>, options: [String: Any], callback: @escaping RCTResponseSenderBlock) {
        super.init(nibName: nil, bundle: nil)
        self.fetchedAssets = fetchedAssets
        self.options = options
        self.globalCallback = callback
        if let title = options["title"] as? String {
            self.title = title
        } else {
            self.title = "Choose Photo"
        }
        let cancelBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.dismissViewController(_:)))
        self.navigationItem.rightBarButtonItem = cancelBarButtonItem
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        self.view.addSubview(self.collectionView)
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        var topAnchor: NSLayoutConstraint? = nil
        if #available(iOS 11.0, *) {
            topAnchor = self.collectionView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 2)
            
        } else {
            topAnchor = self.collectionView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 2)
        }
        let leftAnchor = self.collectionView.leftAnchor.constraint(equalTo: self.view.leftAnchor, constant: 2)
        let bottomAnchor = self.collectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant:  -2)
        let rightAnchor = self.collectionView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -2)
        if let parsedTopAnchor = topAnchor {
            self.view.addConstraints([parsedTopAnchor, leftAnchor, bottomAnchor, rightAnchor])
        }
    }
    
    @objc
    func dismissViewController(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true) { [weak self] in
            guard let `self` = self else { return }
            if let callback = self.globalCallback {
                let callbackResponse: [[String: Any]?] = [nil, ["didCancel": true]]
                callback(callbackResponse as [Any])
            }
        }
    }
}

extension ImageShowerViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let assets = self.fetchedAssets else { return 0 }
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: self.reusableIdentifier, for: indexPath) as? ImageShowerCell else { return UICollectionViewCell() }
        guard let assets = self.fetchedAssets else { return cell }
        let asset = assets.object(at: indexPath.item)
        DispatchQueue.main.async {
            cell.fetchImage(asset: asset)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.layer.frame.width / 3 - 2, height: collectionView.layer.frame.height / 6.5)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 2 // - 2
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let assets = self.fetchedAssets else { return }
        let asset = assets.object(at: indexPath.item)
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = true
        manager.requestImageData(for: asset, options: options) { [weak self] (imageData: Data?, _: String?, _: UIImage.Orientation, _: [AnyHashable : Any]?) in
            guard let `self` = self else { return }
            if let imageData = imageData {
                var pathDirectory: String? = nil
                if let storageOptions = self.options["storageOptions"] as? NSDictionary {
                    if let path = storageOptions.value(forKey: "path") as? String {
                        pathDirectory = path
                    }
                }
                let fileCreateResult = ImageUtil.createCacheFile(imageData: imageData, pathDirectory: pathDirectory, callback: self.globalCallback)
                self.dismiss(animated: true) {
                    guard let callback = self.globalCallback else { return }
                    let callbackResponse: [[String: Any]?] = [
                        nil,
                        fileCreateResult
                    ]
                    callback(callbackResponse as [Any])
                    self.globalCallback = nil
                }
            }
        }
    }
}
