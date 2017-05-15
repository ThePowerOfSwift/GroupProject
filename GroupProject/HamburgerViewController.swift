import UIKit

class HamburgerViewController: UIViewController {
    
    static let sharedInstance = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "HamburgerMenu") as! HamburgerViewController
    
    @IBOutlet weak var menuView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var leftMargainConstraint: NSLayoutConstraint!
    var originalLeftMargin: CGFloat!
    var openPositionLeftMarginConstant: CGFloat!
    var closedPositionLeftMarginConstant: CGFloat!
    
    var menuViewController: MenuViewController!{
        didSet{
            view.layoutIfNeeded()
            menuView.addSubview(menuViewController.view)
        }
    }
    
    var contentViewController: UIViewController! {
        didSet(oldContentViewController){
            view.layoutIfNeeded()
            
            if oldContentViewController != nil {
                oldContentViewController.willMove(toParentViewController: nil)
                oldContentViewController.view.removeFromSuperview()
                oldContentViewController.didMove(toParentViewController: nil)
            }
            
            contentViewController.willMove(toParentViewController: self)
            contentView.addSubview(contentViewController.view)
            contentViewController.didMove(toParentViewController: self)
            
            UIView.animate(withDuration: 0.3, animations: {
                self.leftMargainConstraint.constant = 0
                self.view.layoutIfNeeded()
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup open and closed position constants
        openPositionLeftMarginConstant = self.view.frame.size.width - 50
        closedPositionLeftMarginConstant = 0
    }
    
    override func viewDidLayoutSubviews() {
        //User.sharedInstance.updateUser()
        if User.sharedInstance.nativeCountry == nil {
            
            let storyboard = UIStoryboard(name: "ChooseLocation", bundle: nil)
            let viewController = storyboard.instantiateInitialViewController()
            present(viewController!, animated: true, completion: nil)
        }
    }
    
    func moveMenu() {
        UIView.animate(withDuration: 0.5, delay: 0, options: [],
                       animations: {
                        if self.leftMargainConstraint.constant == 0 {
                            self.leftMargainConstraint.constant = self.view.frame.size.width - 90
                            
                            //self.contentView.layer.transform = self.transformForFraction(fraction: 0.5)

                        } else {
                            self.leftMargainConstraint.constant = 0
                            self.contentView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        }
                        self.view.layoutIfNeeded()
        })
    }
    
    func transformForFraction(fraction:CGFloat) -> CATransform3D {
        var identity = CATransform3DIdentity
        identity.m34 = -1.0 / 100.0;
        let angle = Double(1.0 - fraction) * -M_PI_2
        //let xOffset = contentView.bounds.width * 0.4
        let rotateTransform = CATransform3DRotate(identity, CGFloat(angle), 0.0, 1.0, 0.0)
       // let translateTransform = CATransform3DMakeTranslation(xOffset, 0.5, 0.0)
        let shrink = CATransform3DMakeScale(0.7, 0.7, 0.1)

        return CATransform3DConcat(rotateTransform, shrink)
    }
    
    @IBAction func onPanGesture(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        let velocity = sender.velocity(in: view)

        // Restricts pan gesture, 
        //      towards right when hamburger menu is in open position
        //      towards left when hamburger menu is in closed position
        if ((leftMargainConstraint.constant == closedPositionLeftMarginConstant && velocity.x < 0) ||
            leftMargainConstraint.constant == openPositionLeftMarginConstant && velocity.x > 0) {
            return
        }

        if sender.state == UIGestureRecognizerState.began {
            originalLeftMargin = leftMargainConstraint.constant
        } else if sender.state == UIGestureRecognizerState.changed {
            leftMargainConstraint.constant = originalLeftMargin + translation.x
            
        } else if sender.state == UIGestureRecognizerState.ended{

            UIView.animate(withDuration: 0.3, animations: { 
                if velocity.x > 0 {
                    self.leftMargainConstraint.constant = self.openPositionLeftMarginConstant

                } else {
                    self.leftMargainConstraint.constant = self.closedPositionLeftMarginConstant
                }
                self.view.layoutIfNeeded()

            }, completion: { (_) in
                // Confidently assumes its Dashbaseviewcontroller!
                let viewController = (self.contentViewController as! UINavigationController).viewControllers[0] as! DashBaseViewController
                viewController.HamburgerButton.showsMenu = !viewController.HamburgerButton.showsMenu
            })
        }
    }
}
