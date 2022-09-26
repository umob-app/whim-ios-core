import UIKit
import RxSwift
import RxCocoa

public extension Reactive where Base: UIViewController {
    var viewDidLoad: Observable<Void> {
        return methodInvoked(#selector(UIViewController.viewDidLoad))
            .map { _ in () }
    }

    var viewWillAppear: Observable<Bool> {
        return methodInvoked(#selector(UIViewController.viewWillAppear))
            .compactMap { args in args[0] as? Bool }
    }

    var viewDidAppear: Observable<Bool> {
        return methodInvoked(#selector(UIViewController.viewDidAppear))
            .compactMap { args in args[0] as? Bool }
    }

    var viewWillDisappear: Observable<Bool> {
        return methodInvoked(#selector(UIViewController.viewWillDisappear))
            .compactMap { args in args[0] as? Bool }
    }

    var viewDidDisappear: Observable<Bool> {
        return methodInvoked(#selector(UIViewController.viewDidDisappear))
            .compactMap { args in args[0] as? Bool }
    }
}
