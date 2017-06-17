//
//  Datum.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/16/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

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

indirect enum Datum {
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
    case Port(FileHandle) // TBD
    case Vector([Datum]) // TBD

    var display: String {
        switch self {
        case .Undefined:
            return ""
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
}


// MARK: - Equatable
extension Datum: Equatable {
    /// This should be similar to eq?
    static func==(lhs: Datum, rhs: Datum) -> Bool {
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

// MARK: - CustomStringConvertible
extension Datum: CustomStringConvertible {
    var description: String {
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
}

// MARK: - Unboxing
extension Datum {
    func asSymbol() throws -> String {
        guard case let .Symbol(symbol) = self else {
            throw Exception.General("\(self) must be a symbol")
        }
        return symbol
    }

    func asNumber() throws -> Decimal {
        guard case let .Number(number) = self else {
            throw Exception.General("\(self) must be a number")
        }
        return number
    }

    func asPointer() throws -> Cell {
        guard case let .Pointer(pointer) = self else {
            throw Exception.General("\(self) must be a pair")
        }
        return pointer
    }

    func asProcedure() throws -> Procedure {
        guard case let .Procedure(_, procedure) = self else {
            throw Exception.General("\(self) must be a procedure")
        }
        return procedure
    }
}


// MARK: - Convenience
extension Datum {
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
}


// MARK: - Sequence
extension Datum: Sequence {
    struct Iterator: IteratorProtocol {
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

    func makeIterator() -> Iterator {
        return Iterator(datum: self)
    }
}


// MARK: - Collection
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
