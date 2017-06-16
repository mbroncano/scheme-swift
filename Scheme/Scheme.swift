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
        case (.Undefined, _):
            return ""
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

extension Datum: Collection {
    public typealias Index = Int
    public typealias SubSequence = Slice<Datum>

    public var startIndex: Index { return 0 }
    public var endIndex: Index { return reduce(0, { a, _ in return a + 1 }) }

    public func index(after i: Int) -> Int { return i + 1 }

    public subscript(position: Int) -> Datum {
        guard let result = enumerated().first(where: { return $0.0 == position }) else {
            return .Nil
        }

        return result.1
    }

    public init(slice: SubSequence) {
        self = slice.reversed().reduce(.Nil) { cur, car in
            .Pointer(Cell(car: car, cdr: cur))
        }
    }
}

//extension Cell: Sequence {
//    public struct Iterator: IteratorProtocol {
//        var cell: Cell? = nil
//
//        mutating public func next() -> Cell? {
//            guard let cur = cell else {
//                return nil
//            }
//
//            guard case let .Pointer(next) = cur.cdr else {
//                cell = nil
//                return nil
//            }
//
//            cell = next
//            return cell
//        }
//    }
//
//    public func makeIterator() -> Iterator {
//        return Iterator(cell: self)
//    }
//}

extension Datum: Sequence {
    public struct Iterator: IteratorProtocol {
        var datum: Datum

        // check for dotted list (i.e. datum != .Nil)
        // and decide what to do
        mutating public func next() -> Datum? {
            guard case let .Pointer(cell) = datum else {
                return nil
            }
            datum = cell.cdr
            return cell.car
        }
    }

    public func makeIterator() -> Iterator {
        return Iterator(datum: self)
    }
}

extension Datum {
    public func asSymbol() throws -> String {
        guard case let .Symbol(symbol) = self else {
            throw Exception.General("\(self) must be a symbol")
        }
        return symbol
    }

    public func asNumber() throws -> Decimal {
        guard case let .Number(number) = self else {
            throw Exception.General("\(self) must be a number")
        }
        return number
    }

    public func asPointer() throws -> Cell {
        guard case let .Pointer(pointer) = self else {
            throw Exception.General("\(self) must be a pair")
        }
        return pointer
    }

    public func asProcedure() throws -> Procedure {
        guard case let .Procedure(_, procedure) = self else {
            throw Exception.General("\(self) must be a procedure")
        }
        return procedure
    }
}

public typealias Procedure = (Environment, Datum) throws -> Datum
public class Closure {
    let env: [String: Datum]
    var formal: Datum
    var body: Datum

    init(env: [String: Datum], formal: Datum, body: Datum) {
        self.env = env
        self.formal = formal
        self.body = body
    }

}

/// Datum is the basic data type and contains a value
///
/// - Undefined: An undefined value
/// - Nil: A pointer to the empty list
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
/// - Vector: a vector of objects
public indirect enum Datum: Equatable, CustomStringConvertible {
    case Undefined
    case Nil
    case Pointer(Cell)
    case Number(Decimal)
    case Character(Character)
    case Boolean(Bool)
    case Procedure(String, Procedure)
    case Symbol(String)
    case String(String)
    case SpecialForm(String, (Environment, Datum) throws -> (Datum, Bool))
    case Closure(Closure)
    case Port(FileHandle)
    case Vector([Datum])

    /// Returns true if undefined
    public var isUndefined: Bool {
        guard case .Undefined = self else { return false }
        return true
    }

    /// Returns true if points to ()
    public var isNull: Bool {
        guard case .Nil = self else { return false }
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

    /// Returns true if vector
    public var isVector: Bool {
        guard case .Vector = self else { return false }
        return true
    }

    /// Returns true if number and zero
    public var isZero: Bool {
        guard case let .Number(number) = self, number == 0 else { return false }
        return true
    }

    public var description: String {
        switch self {
        case .Undefined:
            return "#<undefined>"
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
        case let .Closure(closure):
            return "#<closure: @\(closure.formal.display) - \(closure.body.display)>"
        case let .Port(handle):
            return "#<port: @\(handle.fileDescriptor)>"
        case let .Vector(vector):
            return "#<vector: @\(vector)>"
        }
    }

    public var display: String {
        switch self {
        case .Undefined:
            return "???"
        case .Nil:
            return "()"
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
        case let .Vector(vector):
            return "#(" + vector.map { $0.display }.joined(separator: " ") + ")"
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
        case (let .Closure(lhs), let .Closure(rhs)): return lhs === rhs
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

    func close() -> [String: Datum] {
        return stack.reduce([:]) { (acc, frame) in
            var cur = acc
            for (key, value) in frame {
                cur[key] = value
            }
            return cur
        }
    }

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

    func eval_bind(_ formal: Datum, _ args: Datum) throws {
        // bind the variables
        switch formal {
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
    }

    func eval_closure(_ closure: Closure, _ arguments: Datum, _ name: String? = nil) throws -> (Datum, Bool) {
        guard case let .Pointer(body) = closure.body
            else { throw Exception.General("Error in lambda body") }

        // create frame if the last one wasn't create by this same closure
        if let last = stack.last, let owner = last["__owner__"],
            owner == .Closure(closure) {} else {
            var frame = closure.env
            frame["__owner__"] = .Closure(closure)
            self.extend(frame)
            if let name = name {
                define_var(name, .Closure(closure))
            }
        }

        // bind the arguments and the formals
        try eval_bind(closure.formal, eval_args(arguments))

        // evaluate the expressions left to right
        var iter = body
        while true {
            guard case let .Pointer(next) = iter.cdr else { break }
            _ = try eval(iter.car)
            iter = next
        }

        return (iter.car, true)
    }

    func eval_proc(_ proc: Datum, _ arguments: Datum) throws -> Datum {
        switch proc {
        case let .Procedure(_ , procedure):
            let arg = Datum.Pointer(Cell(car: proc, cdr: arguments))
            let res = try procedure(self, arg)
            return res

        case let .Closure(closure):
            let (res, _) = try eval_closure(closure, arguments.asPointer().car)
            return res

        default:
            throw Exception.General("Not a procedure or closure \(proc)")
        }
    }

    func eval_list(_ proc: Datum, _ arguments: Datum) throws -> (Datum, Bool) {
        switch proc {
        case let .Procedure(_ , procedure):
            // TODO: do not send the procedure name
            let arg = try Datum.Pointer(Cell(car: proc, cdr: eval_args(arguments)))
            let res = try procedure(self, arg)
            return (res, false)

        case let .SpecialForm(_, form):
            return try form(self, arguments)

        case let .Closure(closure):
            return try eval_closure(closure, arguments)

        default:
            throw Exception.General("Not a procedure, special form or closure \(proc)")
        }
    }

    // TODO: http://www.r6rs.org/final/html/r6rs/r6rs-Z-H-14.html#node_sec_11.20
    func eval(_ car: Datum) throws -> Datum {
        var car = car
        var result: Datum?
        let cur = stack.count

        while case .none = result {
            switch car {
            case let .Pointer(c):
                let (res, eval) = try eval_list(self.eval(c.car), c.cdr)
                if eval {
                    car = res
                } else {
                    result = res
                }

            case let .Symbol(s):
                result = try resolve(s)

            default:
                result = car
            }
        }

        // remove any created frame
        while cur < stack.count { _ = stack.popLast() }

        return result!
    }

    var stack: [[String: Datum]] = [[:]]

    init() throws {
        for datum in builtin {
            switch datum {
            case let .Procedure(name, _):
                define_var(name, datum)
            case let .SpecialForm(name, _):
                define_var(name, datum)
            default:
                throw Exception.General("Internal error: not a builtin procedure or syntax form\(datum)")
            }
        }
    }
}

