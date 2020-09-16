//
//  NotificationSender.swift
//  awesome_notifications
//
//  Created by Rafael Setragni on 05/09/20.
//

import Foundation

class NotificationSender {

    public static let TAG: String = "NotificationSender"

    private var createdSource:      NotificationSource?
    private var appLifeCycle:       NotificationLifeCycle?
    private var pushNotification:   PushNotification?

    private var created:    Bool = false
    private var displayed:  Bool = false

    public func send(
        createdSource: NotificationSource,
        pushNotification: PushNotification?
    ) throws {

        if (pushNotification == nil){
            throw PushNotificationError.invalidRequiredFields(msg: "PushNotification not valid")
        }

        self.appLifeCycle = SwiftAwesomeNotificationsPlugin.getApplicationLifeCycle()

        try pushNotification!.validate()

        // Keep this way to future thread running
        self.createdSource = createdSource
        self.appLifeCycle = SwiftAwesomeNotificationsPlugin.appLifeCycle
        self.pushNotification = pushNotification

        self.execute()
    }

    private func execute(){
        DispatchQueue.global(qos: .background).async {
            
            let notificationReceived:NotificationReceived? = self.doInBackground()

            DispatchQueue.main.async {
                self.onPostExecute(receivedNotification: notificationReceived)
            }
        }
    }
    
    /// AsyncTask METHODS BEGIN *********************************

    private func doInBackground() -> NotificationReceived? {
        
        do {

            if (pushNotification != nil){

                var receivedNotification: NotificationReceived? = nil

                if(pushNotification!.content!.createdDate == nil){
                    pushNotification!.content!.createdSource = self.createdSource
                    pushNotification!.content!.createdDate = DateUtils.getUTCDate()
                    created = true
                }

                if(pushNotification!.content!.createdLifeCycle == nil){
                    pushNotification!.content!.createdLifeCycle = self.appLifeCycle
                }

                if (
                    !StringUtils.isNullOrEmpty(pushNotification!.content!.title) ||
                    !StringUtils.isNullOrEmpty(pushNotification!.content!.body)
                ){

                    if(pushNotification!.content!.displayedLifeCycle == nil){
                        pushNotification!.content!.displayedLifeCycle = appLifeCycle
                    }

                    pushNotification!.content!.displayedDate = DateUtils.getUTCDate()

                    pushNotification = showNotification(pushNotification!)

                    // Only save DisplayedMethods if pushNotification was created and displayed successfully
                    if(pushNotification != nil){
                        displayed = true

                        receivedNotification = NotificationReceived(pushNotification!.content)

                        receivedNotification!.displayedLifeCycle = receivedNotification!.displayedLifeCycle == nil ?
                            appLifeCycle : receivedNotification!.displayedLifeCycle
                    }

                } else {
                    receivedNotification = NotificationReceived(pushNotification!.content);
                }

                return receivedNotification;
            }

        } catch {
        }

        pushNotification = nil
        return nil
    }

    private func onPostExecute(receivedNotification:NotificationReceived?) {

        // Only broadcast if pushNotification is valid
        if(receivedNotification != nil){

            if(created){
                if(SwiftAwesomeNotificationsPlugin.getApplicationLifeCycle() == .AppKilled){
                    CreatedManager.saveCreated(received: receivedNotification!)
                } else {
                    SwiftAwesomeNotificationsPlugin.instance!.createEvent(notificationReceived: receivedNotification!)
                }
            }

            if(displayed){
                if(SwiftAwesomeNotificationsPlugin.getApplicationLifeCycle() == .AppKilled){
                    DisplayedManager.saveDisplayed(received: receivedNotification!)
                } else {
                    SwiftAwesomeNotificationsPlugin.instance!.displayEvent(notificationReceived: receivedNotification!)
                }
            }
        }
    }

    /// AsyncTask METHODS END *********************************

    public func showNotification(_ pushNotification:PushNotification) -> PushNotification? {

        do {
            
            return try NotificationBuilder.createNotification(pushNotification)

        } catch {
            
        }
        
        return nil
    }

    public static func cancelNotification(id:Int) {
        NotificationBuilder.cancelNotification(id: id)
        CreatedManager.removeCreated(id: id)
        DisplayedManager.removeDisplayed(id: id)
    }

    public static func cancelAllNotifications() -> Bool {
        NotificationBuilder.cancellAllNotifications()
        CreatedManager.cancelAllCreated()
        DisplayedManager.cancelAllDisplayed()
        return true;
    }

}
