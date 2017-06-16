//
//  main.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

let environment = try Environment()

while true {
    do {
        print("> ", terminator: "")
        if let input = readLine() {
            try print(environment.readLine(input: input))
        }
    } catch {
        print(error)
    }
}
