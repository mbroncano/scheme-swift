//
//  Node.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/8/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

/// Helper record used for parsing textual expressions
///
/// - Atom: A string containing an atom
/// - List: An array of atoms
public indirect enum Node: CustomStringConvertible {
    case Atom(String)
    case List([Node])

    public var description: String {
        switch self {
        case let .Atom(string):
            return "#<\(string)>"
        case let .List(list):
            return "(" + list.map{ "\($0)" }.joined(separator: " ") + ")"
        }
    }

    public var isQuote: Bool {
        guard case let .Atom(text) = self, text == "'" else { return false }
        return true
    }

    public var isDot: Bool {
        guard case let .Atom(text) = self, text == "." else { return false }
        return true
    }

    func car() -> Datum {
        switch self {
        case let .Atom(text):
            switch text {
            case "":
                return .Nil
            case "#t":
                return .Boolean(true)
            case "#f":
                return .Boolean(false)
            default:
                if let _ = Float(text), let number = Decimal(string: text) {
                    return .Number(number)
                } else if let start = text.first, start == "\"" {
                    return .String(String(text.dropFirst().dropLast()))
                } else {
                    return .Symbol(text)
                }
            }
        case let .List(list):
            var last: Datum = .Nil
            for cell in list.reversed() {
                if cell.isQuote {
                    var lastcdr: Datum = .Nil
                    if case let .Pointer(lastcell) = last {
                        lastcdr = lastcell.cdr
                        lastcell.cdr = .Nil
                    }
                    let quote = Cell(car: .Symbol("quote"), cdr: last)
                    let list = Cell(car: .Pointer(quote), cdr: lastcdr)
                    last = .Pointer(list)
                } else if cell.isDot {
                    if case let .Pointer(lastcell) = last {
                        last = lastcell.car
                    }
                } else {
                    let new = Cell(car: cell.car(), cdr: last)
                    last = .Pointer(new)
                }
            }
            return last
        }
    }

    init(_ string: String) throws {
        var iter = string.characters.makeIterator()
        var text = ""
        var stack: [Node] = [.List([])]

        let add = {
            if !text.isEmpty {
                guard let last = stack.popLast(), case let .List(list) = last
                    else { throw Exception.General("Parsing") }

                stack.append(.List( list + [.Atom(text)]))
                text = ""
            }
        }

        var string = false
        while let c = iter.next() {
            if c == "\"" {
                if string {
                    text.append(c)
                    try add()
                } else {
                    try add()
                    text.append(c)
                }

                string = !string
                continue
            }

            if string {
                text.append(c)
                continue
            }

            switch c {
            case "\"":
                if string {

                } else {
                    string = true
                }

            case ";":
                while let n = iter.next(), n != "\n" {}

            case "(":
                try add()
                stack.append(.List([]))

            case ")":
                guard let last = stack.popLast(), case var .List(list) = last
                    else { throw Exception.General("Parsing") }

                if !text.isEmpty {
                    list.append(.Atom(text))
                    text = ""
                }

                guard let prev = stack.popLast(), case let .List(plist) = prev
                    else { throw Exception.General("Parsing") }

                stack.append(.List( plist + [.List(list)] ))

            case " ", "\n":
                try add()

            case "'":
                if text.isEmpty {
                    text = "'"
                    try add()
                }

            default:
                text.append(c)
            }
        }
        try add()

        guard let first = stack.first else { throw Exception.General("Umatched parenthesis") }
        self = first
    }

    static func parse(_ string: String) -> Datum {
        do {
            return try Node.init(string).car()
        } catch {
            return .Nil
        }
    }
}

