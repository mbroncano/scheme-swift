//
//  Closure.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/16/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

typealias Procedure = (Environment, Datum) throws -> Datum

class Closure {
    let env: [String: Datum]
    var formal: Datum
    var body: Datum

    init(env: [String: Datum], formal: Datum, body: Datum) {
        self.env = env
        self.formal = formal
        self.body = body
    }

}
