//
//  Cell.swift
//  Scheme
//
//  Created by Manuel Broncano on 6/16/17.
//  Copyright © 2017 Manuel Broncano. All rights reserved.
//

import Foundation

/// Cell is fondation class, contains a pair of two values
class Cell: CustomStringConvertible {
    var car: Datum
    var cdr: Datum

    init(car: Datum, cdr: Datum) {
        self.car = car
        self.cdr = cdr
    }

    var description: String {
        return "#(\(car), \(cdr))"
    }

    var display: String {
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

extension Cell: Sequence {
    public struct Iterator: IteratorProtocol {
        var cell: Cell? = nil

        mutating public func next() -> Cell? {
            guard let cur = cell else {
                return nil
            }

            guard case let .Pointer(next) = cur.cdr else {
                cell = nil
                return nil
            }

            cell = next
            return cell
        }
    }

    public func makeIterator() -> Iterator {
        return Iterator(cell: self)
    }
}

