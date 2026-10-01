func rawStrings(name: String) {
    let literal = #"raw \(not interpolated) \n literal"#
    let interpolated = #"value: \#(name.count)"#
    let twoHashes = ##"value: \##(name.count)"##
    let unicode = #"héllo wörld 🎉"#
    // MATCH: a call following raw strings must remain visible.
    sink(literal + interpolated + twoHashes + unicode)
    // A string containing call-like text is not a call.
    let notACall = #"sink(secret)"#
    print(notACall)
}
