//
//  Scheme.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/5/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

public enum Exception: Error {
    case General(String)
}

/// Cell is fondation class, contains a pair of two values
public class Cell: CustomStringConvertible {
    var car: Datum
    var cdr: Datum

    init(car: Datum, cdr: Datum) {
        self.car = car
        self.cdr = cdr
    }

    public var description: String {
        return "#(\(car), \(cdr))"
    }

    public var display: String {
        switch (car, cdr) {
        case (.Nil, _):
            return "\(cdr.display)"
        case (_, .Nil):
            return car.display
        case (_, let .Pointer(cell)):
            return "\(car.display) \(cell.display)"
        default:
            return "\(car.display) . \(cdr.display)"
        }
    }

    /// Returns true if this is the empty list
    public var isEmptyList: Bool {
        guard case (.Nil, .Nil) = (car, cdr) else { return false }
        return true
    }

    /// Returns the next cell in the list when possible
    ///
    /// - Returns: An optional cell
    public func next() -> Cell? {
        if case let .Pointer(result) = cdr {
            return result
        }
        return nil
    }
}

public typealias Procedure = (Environment, Datum) throws -> Datum


/// Datum is the basic data type and contains a value
///
/// - Nil: An undefined
/// - Pointer: A reference to a cell
/// - Number: A decimal number
/// - Character: A single character
/// - Boolean: A boolean value
/// - Procedure: A pointer to a built-in procedure
/// - Symbol: An interned symbol
/// - String: A character string
/// - SpecialFormt: A pointer to an internal form
/// - Closure: A lambda closure
/// - Port: a file port
public indirect enum Datum: Equatable, CustomStringConvertible {
    case Nil
    case Pointer(Cell)
    case Number(Decimal)
    case Character(Character)
    case Boolean(Bool)
    case Procedure(String, Procedure)
    case Symbol(String)
    case String(String)
    case SpecialForm(String, (Environment, Datum) throws -> (Datum, Bool))
    case Closure([String:Datum], Datum)
    case Port(FileHandle)

    /// Returns true if undefined
    public var isNil: Bool {
        guard case .Nil = self else { return false }
        return true
    }

    /// Returns true if points to ()
    public var isNull: Bool {
        guard case let .Pointer(cell) = self, cell.isEmptyList else { return false }
        return true
    }

    /// Returns true if #t
    public var isTrue: Bool {
        guard case let .Boolean(bool) = self else { return true }
        return bool
    }

    /// Returns true if number
    public var isNumber: Bool {
        guard case .Number = self else { return false }
        return true
    }

    /// Returns true if string
    public var isString: Bool {
        guard case .String = self else { return false }
        return true
    }

    /// Returns true if symbol
    public var isSymbol: Bool {
        guard case .Symbol = self else { return false }
        return true
    }

    /// Returns true if pair
    public var isPair: Bool {
        guard case .Pointer = self else { return false }
        return true
    }

    /// Returns true if port
    public var isPort: Bool {
        guard case .Port = self else { return false }
        return true
    }

    /// Returns true if number and zero
    public var isZero: Bool {
        guard case let .Number(number) = self, number == 0 else { return false }
        return true
    }

    public var description: String {
        switch self {
        case .Nil:
            return "#<nil>"
        case let .Pointer(cell):
            return "#<cell: \(cell)>"
        case let .Number(number):
            return "#<number: \(number)>"
        case let .Boolean(value):
            return "#<boolean: \(value)>"
        case let .Character(value):
            return "#<character: \(value)>"
        case let .Symbol(string):
            return "#<symbol: @\(string)>"
        case let .String(string):
            return "#<string: \"@\(string)\">"
        case let .Procedure(name, _):
            return "#<procedure: @\(name)>"
        case let .SpecialForm(name, _):
            return "#<special: @\(name)>"
        case let .Closure(_, formal):
            return "#<closure: @\(formal)>"
        case let .Port(handle):
            return "#<port: @\(handle.fileDescriptor)>"
        }
    }

    public var display: String {
        switch self {
        case .Nil:
            return ""
        case let .Symbol(string):
            return string
        case let .String(string):
            return "\"\(string)\""
        case let .Number(value):
            return "\(value)"
        case let .Character(char):
            return "#\\\(char)"
        case let .Boolean(value):
            return (value ? "#t" : "#f")
        case let .Pointer(cell):
            return "(\(cell.display))"
        default:
            return "\(self)"
        }
    }

    /// This should be similar to eq?
    static public func==(lhs: Datum, rhs: Datum) -> Bool {
        switch (lhs, rhs) {
        case (.Nil, .Nil): return true
        case (let .Boolean(lhs), let .Boolean(rhs)): return lhs == rhs
        case (let .Number(lhs), let .Number(rhs)): return lhs == rhs
        case (let .Character(lhs), let .Character(rhs)): return lhs == rhs
        case (let .String(lhs), let .String(rhs)): return lhs == rhs
        case (let .Symbol(lhs), let .Symbol(rhs)): return lhs == rhs
        case (let .Pointer(lhs), let .Pointer(rhs)): return lhs === rhs
        case (let .Procedure(lhs, _), let .Procedure(rhs, _)): return lhs == rhs
        default: return false
        }
    }
}

public class Environment {

    func resolve(_ symbol:String) throws -> Datum {
        for frame in self.stack.reversed() {
            if let value = frame[symbol] {
                return value
            }
        }
        throw Exception.General("Unbound symbol: \(symbol)")
    }

    func extend(_ ext: [String:Datum] = [:]) {
        self.stack.append(ext)
    }

    func unextend() {
        _ = self.stack.popLast()
    }

    func define_var(_ symbol: String, _ value: Datum) {
        if var last = stack.popLast() {
            last[symbol] = value
            stack.append(last)
        }
    }

    func define(_ first: Cell, evaluate: Bool = true) throws {
        if case let .Symbol(symbol) = first.car {
            var value: Datum = .Nil
            if case let .Pointer(def) = first.cdr {
                value = evaluate ? try eval(def.car) : def.car
            }

            define_var(symbol, value)

        } else if case let .Pointer(lambda) = first.car {
            guard case .Pointer = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            guard case let .Symbol(symbol) = lambda.car
                else { throw Exception.General("Lambda name must be a symbol") }

            define_var(symbol, .Closure(close(), .Pointer(Cell(car: lambda.cdr, cdr: first.cdr))))

        } else {
            throw Exception.General("Define must be a symbol or a lambda")
        }
    }

    func close() -> [String: Datum] {
        return stack.reduce([:]) { (acc, frame) in
            var cur = acc
            for (key, value) in frame {
                cur[key] = value
            }
            return cur
        }
    }

    func addBuiltin(_ builtin: Datum) throws {
        guard case let .Procedure(name, _) = builtin
            else { throw Exception.General("Internal error: not a builtin procedure") }

        if var first = stack.first {
            first[name] = builtin
            stack = [first] + stack.dropFirst()
        }
    }

    var stack: [[String: Datum]] = [[

        "lambda": .SpecialForm("lambda", { env, cell in
            guard case let .Pointer(first) = cell, case .Pointer = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            return (.Closure(env.close(), cell), false)
        }),
        "let": .SpecialForm("let", { env, cell in
            // TODO: add support for named letrec
            guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }


            if case let .Symbol(vars) = first.car {

            }

            guard case var .Pointer(vars) = first.car
                else { throw Exception.General("First parameter must be a list") }

            // evaluate the formals
            var cdr = vars.cdr
            while true {
                guard case let .Pointer(formal) = vars.car else { throw Exception.General("Expected format to be lists") }
                try env.define(formal)

                guard case let .Pointer(next) = vars.cdr else { break }
                vars = next
            }

            // evaluate the expressions left to right
            var result: Datum = .Nil
            var body = second
            while true {
                guard case let .Pointer(next) = body.cdr
                    else { return (body.car, true) }
                _ = try env.eval(body.car)
                body = next
            }

            // return the last result
            //return (.Nil, false)
        }),
        "if": .SpecialForm("if", { env, cell in
            guard case let .Pointer(first) = cell, case let .Pointer(second) = first.cdr
                else { throw Exception.General("Must provide at least two parameters") }

            if try env.eval(first.car).isTrue {
                return (second.car, true)
            }

            if case let .Pointer(third) = second.cdr {
                return (third.car, true)
            }

            return (.Nil, false)
        }),

        "else": .Boolean(true),
        "cond": .SpecialForm("cond", { env, cell in
            guard case var .Pointer(arg) = cell
                else { throw Exception.General("Must provide at least one parameters") }

            while true {
                guard case var .Pointer(clause) = arg.car
                    else { throw Exception.General("Clause must be a list") }
                let pred = try env.eval(clause.car)
                if pred.isTrue {
                    guard case var .Pointer(exp) = clause.cdr else { return (pred, false) }
                    while true {
                        let res = try env.eval(exp.car)
                        guard case let .Pointer(next) = exp.cdr else { return (res, false) }
                        exp = next
                    }
                    break
                }
                guard let nextClause = arg.next() else { break }
                arg = nextClause
            }

            return (.Nil, false)
        }),

        "quote": .SpecialForm("quote", { env, cell in
            guard case let .Pointer(first) = cell
                else { throw Exception.General("Must provide at least a parameter") }

            return (first.car, false)
        }),
        "define": .SpecialForm("define", { env, cell in
            guard case let .Pointer(first) = cell
                else { throw Exception.General("Must provide at least a parameter") }

            try env.define(first)

            return (.Nil, false)
        })]]

    func eval_args(_ datum: Datum) throws -> Datum {
        if case let .Pointer(cell) = datum {
            let ecar = try eval(cell.car)
            let ecdr = try eval_args(cell.cdr)
            let ecell = Cell(car: ecar, cdr: ecdr)
            return .Pointer(ecell)
        } else if case let .Symbol(symbol) = datum {
            return try resolve(symbol)
        } else {
            return datum
        }

        // ... or the iterative version
//        var it = c
//        var dd = [Datum]()
//        while let next = it.next() {
//            dd.append(try eval(next.car))
//            it = next
//        }
//        
//        let arg: Datum = dd.reversed().reduce(it.cdr, { acc, ptr in
//            return .Pointer(Cell(car: ptr, cdr: acc))
//        })


    }

    // TODO: http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-14.html#node_sec_11.20
    func eval(_ car: Datum, _ tail: Bool = false) throws -> Datum {

        var car = car
        var result: Datum = .Nil
        var tail = tail

        repeat {
            if case let .Pointer(c) = car {
                let e = try eval(c.car)
                if case let .Procedure(_ , proc) = e {

                    let arg = try eval_args(c.cdr)

                    // we actually ignore the first 'car'
                    result = try proc(self, .Pointer(Cell(car: e, cdr: arg)))
                    break;

                } else if case let .SpecialForm(_, form) = e {

                    let (res, eval) = try form(self, c.cdr)
                    if !eval {
                        result = res
                        break
                    }

                    tail = true
                    car = res

                } else if case let .Closure(frame, lambda) = e {
                    if !tail {
                        extend(frame)
                    }

//                    if case .Pointer = c.cdr {
                    let args = try eval_args(c.cdr)

                    guard case let .Pointer(formal) = lambda, case let .Pointer(body) = formal.cdr
                        else { throw Exception.General("Error in lambda formal and/or body") }

                    // bind the variables
                    switch formal.car {
                    case .Nil:
                        break

                    case let .Symbol(symbol):
                        define_var(symbol, args)

                    case var .Pointer(list):
                        var args = args
                        while true {
                            guard case let .Symbol(symbol) = list.car,
                                case let .Pointer(value) = args
                                else { break }
                            define_var(symbol, value.car)

                            if case let .Pointer(next) = list.cdr {
                                list = next
                            } else if case let .Symbol(rest) = list.cdr {
                                define_var(rest, value.cdr)
                                break
                            } else if case .Nil =  list.cdr {
                                break
                            } else {
                                throw Exception.General("The 'rest' parameter should be a symbol \(list.cdr)")
                            }

                            guard case .Pointer = value.cdr else { break }
                            args = value.cdr
                        }

                    default:
                        throw Exception.General("Formal must be a list, symbol or nothing")
                    }

                    // evaluate the expressions left to right
                    var iter = body
                    while true {
                        guard case let .Pointer(next) = iter.cdr else { break }
                        result = try eval(iter.car)
                        iter = next
                    }

                    tail = true
                    car = iter.car

                } else {
                    throw Exception.General("Not a procedure, special form or closure \(e)")
                }
            } else if case let .Symbol(s) = car {
                result = try resolve(s)
                break;
            } else {
                result = car
                break;
            }
        } while true

        if tail {
            unextend()
        }

        return result
    }

    init() throws {
        for datum in builtin {
            try addBuiltin(datum)
        }
    }
}

