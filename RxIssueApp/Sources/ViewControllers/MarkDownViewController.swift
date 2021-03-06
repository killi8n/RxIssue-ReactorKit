//
//  MarkDownViewController.swift
//  RxIssueApp
//
//  Created by killi8n on 2018. 9. 6..
//  Copyright © 2018년 killi8n. All rights reserved.
//

import UIKit
import Down
import Then
import SnapKit
import RxViewController
import ReactorKit
import RxSwift
import RxCocoa

class MarkDownViewController: BaseViewController, View {
    typealias Reactor = MarkDownViewReactor
    
    init(reactor: Reactor, comment: Model.Comment, owner: String, repo: String, indexPath: IndexPath, parentIndexPath: IndexPath) {
        super.init()
        
        self.reactor = reactor
        self.comment = comment
        self.owner = owner
        self.repo = repo
        self.indexPath = indexPath
        self.parentIndexPath = parentIndexPath
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var comment: Model.Comment!
    var owner: String!
    var repo: String!
    var indexPath: IndexPath!
    var parentIndexPath: IndexPath!
    
    let downView = try? DownView(frame: .zero, markdownString: "")
    
    let editButton: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit, target: nil, action: nil)
    
    let provider = ServiceProvider()
    
    var deleteFlag: BehaviorRelay<Bool> = BehaviorRelay(value: false)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        self.title = "Mark Down Version"
        
        guard let downView = self.downView else { return }
        self.view.addSubview(downView)
        
        guard let comment = self.comment else { return }
        guard let userInfo = self.provider.userDefaultsService.value(forKey: .userInfo) else { return }
        guard let login = userInfo["login"] as? String else { return }
        if comment.user.login == login {
            self.navigationItem.rightBarButtonItem = self.editButton
        }
    }
    
    override func setupConstraints() {
        guard let downView = self.downView else { return }
        downView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
    }
    
    func bind(reactor: Reactor) {
        self.rx.viewDidLoad.flatMap { [weak self] _ -> Observable<Model.Comment> in
            guard let comment = self?.comment else { return .empty() }
            return Observable.just(comment)
            }.map { (comment) -> Reactor.Action in
                return Reactor.Action.updateMarkDown(comment.body)
        }.bind(to: reactor.action).disposed(by: self.disposeBag)
        
        self.editButton.rx.tap.subscribe(onNext: { [weak self] _ in
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
            alert.addAction(UIAlertAction(title: "Edit", style: UIAlertActionStyle.default, handler: { [weak self] _ in
                let githubService = reactor.githubService
                let reactor = EditCommentViewReactor(githubService: githubService)
                guard let owner = self?.owner, let repo = self?.repo, let comment = self?.comment else { return }
                let editView = EditCommentViewController(reactor: reactor, comment: comment, owner: owner, repo: repo)
                let navi = UINavigationController(rootViewController: editView)
                self?.present(navi, animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { [weak self] _ in
                self?.deleteFlag.accept(true)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        }).disposed(by: self.disposeBag)
        
        self.deleteFlag
            .distinctUntilChanged()
            .filter { $0 }
            .flatMap({ [weak self] _ -> Observable<(String, String, Int, IndexPath, IndexPath)> in
                guard let owner = self?.owner, let repo = self?.repo else { return .empty() }
                guard let commentId = self?.comment.id else { return .empty() }
                guard let indexPath = self?.indexPath, let parentIndexPath = self?.parentIndexPath else { return .empty() }
                return Observable.just((owner, repo, commentId, indexPath, parentIndexPath))
            })
            .map { (owner, repo, commentId, indexPath, parentIndexPath) -> Reactor.Action in
                return Reactor.Action.deleteComment(owner: owner, repo: repo, commentId: commentId, indexPath: indexPath, parentIndexPath: parentIndexPath)
        }.bind(to: reactor.action).disposed(by: self.disposeBag)

        
        
        reactor.state.map { $0.markDown }
            .distinctUntilChanged()
            .filter { markDown -> Bool in
                return !markDown.isEmpty
            }.subscribe(onNext: { [weak self] (markDown) in
                guard let downView = self?.downView else { return }
                try? downView.update(markdownString: markDown)
            }).disposed(by: self.disposeBag)
        
        reactor.state.map { $0.deleted }
            .distinctUntilChanged()
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in
                self?.deleteFlag.accept(false)
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: self.disposeBag)
        
        reactor.state.map { $0.isDismissed }
            .distinctUntilChanged()
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            .disposed(by: self.disposeBag)
        
    }
    
    
    
}
