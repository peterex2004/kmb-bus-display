/// Pure reminder threshold and latch logic.
public enum ReminderEngine {
    public static func nextLead(_ currentLeadMin: Int?) -> ReminderLead {
        guard let currentLeadMin,
              let currentIndex = BoardConstants.reminderLeads.firstIndex(of: currentLeadMin)
        else {
            return ReminderLead(remindMe: true, remindLeadMin: BoardConstants.reminderLeads[0])
        }

        if currentIndex == BoardConstants.reminderLeads.count - 1 {
            return ReminderLead(remindMe: false, remindLeadMin: nil)
        }

        return ReminderLead(
            remindMe: true,
            remindLeadMin: BoardConstants.reminderLeads[currentIndex + 1]
        )
    }

    public static func evaluate(_ state: ReminderState, now: Int?) -> ReminderEvaluation {
        guard state.remindMe == true else {
            return ReminderEvaluation(shouldNotify: false, notifiedEta: nil, minutes: nil)
        }

        guard let nearestEta = state.nearestEta else {
            return ReminderEvaluation(
                shouldNotify: false,
                notifiedEta: state.notifiedEta,
                minutes: nil
            )
        }

        guard let now, let leadMs = state.leadMs else {
            return ReminderEvaluation(
                shouldNotify: false,
                notifiedEta: state.notifiedEta,
                minutes: nil
            )
        }

        let minutes = (Double(nearestEta) - Double(now)) / 60_000.0
        if let notifiedEta = state.notifiedEta {
            let difference = abs(nearestEta - notifiedEta)
            let sameBus = difference <= BoardConstants.rearmToleranceMs
            let newerBus = nearestEta > notifiedEta + BoardConstants.rearmToleranceMs

            if sameBus || !newerBus {
                return ReminderEvaluation(
                    shouldNotify: false,
                    notifiedEta: notifiedEta,
                    minutes: minutes
                )
            }
        }

        if minutes <= Double(leadMs) / 60_000.0 {
            return ReminderEvaluation(
                shouldNotify: true,
                notifiedEta: nearestEta,
                minutes: minutes
            )
        }

        return ReminderEvaluation(shouldNotify: false, notifiedEta: nil, minutes: minutes)
    }
}
