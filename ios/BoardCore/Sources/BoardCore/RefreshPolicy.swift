/// Foreground visibility predicate for board refresh work.
public enum RefreshPolicy {
    public static func shouldRun(hidden: Bool?, boardActive: Bool?) -> Bool {
        hidden != true && boardActive == true
    }
}
