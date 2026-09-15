/* Outer comment.
   /* Nested comment. */
*/
func rawStrings(name: String) -> String {
    let multiline = """
    Dear \(name),
    line two with "quotes"
    """
    let literal = #"raw \(not interpolated) \n literal"#
    let interpolated = #"value: \#(name.count)"#
    let twoHashes = ##"value: \##(name.count), single hash #"##
    let unicode = #"héllo wörld 🎉"#
    let following = #"independent string"#
    return multiline + literal + interpolated + twoHashes + unicode + following
}
