
public indirect enum Type {
    case Raw(String)
    case Declaration(TypeDeclaration)

    public func write<Stream: TextOutputStream>(identifier: String?, to stream: inout Stream) {
        switch self {
            case let .Raw(raw):
                raw.write(to: &stream)
                if let identifier {
                    " \(identifier)".write(to: &stream)
                }

            case let .Declaration(declaration):
                declaration.write(identifier: identifier, to: &stream)
        }
    }
}

public extension Type {
    init(name: String) {
        self = .Declaration(.init(name: name))
    }

    init(struct name: String) {
        self = .Declaration(.init(struct: name))
    }
}

// See Section "6.7 Declarations" in the C standard
// http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf.
//
// inspired by https://github.com/mozilla/cbindgen CDecl
//
public struct TypeDeclaration {

    public enum TypeQualifier: String {
        case Const = "const"
    }

    public enum TypeSpecifier {
        case Name(String)
        case Struct(String)
    }

    public enum Declarator {
        case Pointer(isConst: Bool)
        case Array(size: Int?)
    }

    public var typeQualifers: [TypeQualifier]
    public var typeSpecifier: TypeSpecifier
    public var declarators: [Declarator]

    public init(
        typeQualifers: [TypeQualifier] = [],
        typeSpecifier: TypeSpecifier,
        declarators: [Declarator] = []
    ) {
        self.typeQualifers = typeQualifers
        self.typeSpecifier = typeSpecifier
        self.declarators = declarators
    }

    public func write<Stream: TextOutputStream>(identifier: String?, to stream: inout Stream) {

        // Write the type qualifiers first
        for typeQualifier in typeQualifers {
            typeQualifier.rawValue.write(to: &stream)
            " ".write(to: &stream)
        }

        // Write the type specifier next
        switch typeSpecifier {
            case let .Name(name):
                name.write(to: &stream)
            case let .Struct(name):
                "struct \(name)".write(to: &stream)
        }

        // When we have an identifier, put a space between the type specifier and the declarators
        if identifier != nil {
            " ".write(to: &stream)
        }

        // Write the left part of declarators before the identifier
        for (index, declarator) in declarators.enumerated().reversed() {
            let nextIsPointer: Bool
            if index <= 1 {
                nextIsPointer = false
            } else if case .Pointer = declarators[index - 1] {
                nextIsPointer = true
            } else {
                nextIsPointer = false
            }

            switch declarator {
                case let .Pointer(isConst: isConst):
                    "*".write(to: &stream)
                    if isConst {
                        "const ".write(to: &stream)
                    }

                case .Array:
                    if nextIsPointer {
                        "(".write(to: &stream)
                    }
            }
        }

        // Write the identifier, if any
        if let identifier {
            identifier.write(to: &stream)
        }

        // Write the right part of declarators after the identifier
        var lastWasPointer = false

        for declarator in declarators {
            switch declarator {
                case .Pointer:
                    lastWasPointer = true

                case let .Array(size):
                    if lastWasPointer {
                        ")".write(to: &stream)
                    }
                    lastWasPointer = false

                    "[\(size.map(String.init) ?? "")]".write(to: &stream)
            }
        }
    }
}

public extension TypeDeclaration {

    init(name: String) {
        self.init(typeSpecifier: .Name(name))
    }

    init(struct name: String) {
        self.init(typeSpecifier: .Struct(name))
    }

    // Signed
    static let Char = Self(name: "char")
    static let Int = Self(name: "int")
    static let Short = Self(name: "short")
    static let Long = Self(name: "long")
    static let LongLong = Self(name: "long long")

    static let SignedChar = Self(name: "signed char")
    static let SignedInt = Self(name: "signed int")
    static let SignedShort = Self(name: "signed short")
    static let SignedLong = Self(name: "signed long")
    static let SignedLongLong = Self(name: "signed long long")

    // Unsigned
    static let UnsignedChar = Self(name: "unsigned char")
    static let UnsignedInt = Self(name: "unsigned int")
    static let UnsignedShort = Self(name: "unsigned short")
    static let UnsignedLong = Self(name: "unsigned long")
    static let UnsignedLongLong = Self(name: "unsigned long long")

    // Floating point
    static let Float = Self(name: "float")
    static let Double = Self(name: "double")
    static let LongDouble = Self(name: "long double")

    // Other
    static let Void = Self(name: "void")
    static let Bool = Self(name: "bool")
    static let _Bool = Self(name: "_Bool")
    static let _Complex = Self(name: "_Complex")
    static let ID = Self(name: "id")
}

public protocol Element {

    func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>)
}

public struct Indentation: Element {

    public init() {}

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        writer.currentIndentation.write(to: &writer)
    }
}

public struct Raw: Element {

    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        raw.write(to: &writer)
    }
}

public let Newline = Raw("\n")
public let Semicolon = Raw(";")

public enum IncludeStyle {
    case Quotes
    case AngularBrackets
}

public struct Include: Element {
    public let file: String
    public let style: IncludeStyle

    public init(file: String, style: IncludeStyle) {
        self.file = file
        self.style = style
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "#include ".write(to: &writer)
        switch style {
        case .Quotes:
            "\"\(file)\"".write(to: &writer)
        case .AngularBrackets:
            "<\(file)>".write(to: &writer)
        }
        Newline.write(to: &writer)
    }
}

public typealias Body = () -> [Element]

public struct Indented: Element {

    public let body: Body

    public init(@CBuilder body: @escaping Body) {
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        writer.currentIndentation.append(writer.indentation)
        for Element in body() {
            Indentation().write(to: &writer)
            Element.write(to: &writer)
        }
        writer.currentIndentation.removeLast(writer.indentation.count)
    }
}

public struct Braced: Element {

    public let body: Body

    public init(@CBuilder body: @escaping Body) {
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "{".write(to: &writer)
        let elements = body()
        if !elements.isEmpty {
            Newline.write(to: &writer)
        }
        Indented { elements }.write(to: &writer)
        "}".write(to: &writer)
    }
}

public struct Parameter: Element {
    public let identifier: String?
    public let type: Type

    public init(identifier: String? = nil, type: Type) {
        self.identifier = identifier
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        type.write(
            identifier: identifier,
            to: &writer.stream
        )
    }
}

public struct Field: Element {
    public let identifier: String
    public let type: Type

    public init(identifier: String, type: Type) {
        self.identifier = identifier
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        type.write(
            identifier: identifier,
            to: &writer
        )
        Semicolon.write(to: &writer)
        Newline.write(to: &writer)
    }
}

public struct Function: Element {

    public let returnType: Type
    public let identifier: String
    public let parameters: [Parameter]
    public let body: Body

    public init(
        returnType: Type,
        identifier: String,
        parameters: [Parameter] = [],
        @CBuilder body: @escaping Body = { [ ] }
    ) {
        self.returnType = returnType
        self.identifier = identifier
        self.parameters = parameters
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        returnType.write(
            identifier: identifier,
            to: &writer
        )
        ParameterList(parameters: parameters).write(to: &writer)
        let body = body()
        if body.isEmpty {
            Semicolon.write(to: &writer)
        } else {
            " ".write(to: &writer)
            Braced { body }.write(to: &writer)
        }
        Newline.write(to: &writer)
    }
}

public struct ParameterList: Element {

    public let parameters: [Parameter]

    public init(parameters: [Parameter]) {
        self.parameters = parameters
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "(".write(to: &writer)
        for (index, parameter) in parameters.enumerated() {
            if index > 0 {
                ", ".write(to: &writer)
            }
            parameter.write(to: &writer)
        }
        ")".write(to: &writer)
    }
}

public struct Typedef: Element {

    public let identifier: String
    public let type: Type

    public init(identifier: String, type: Type) {
        self.identifier = identifier
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "typedef ".write(to: &writer)
        type.write(
            identifier: identifier,
            to: &writer
        )
        Semicolon.write(to: &writer)
        Newline.write(to: &writer)
    }
}

public struct Struct: Element {

    public let identifier: String
    public let body: Body

    public init(
        identifier: String,
        @CBuilder body: @escaping Body = { [ ] }
    ) {
        self.identifier = identifier
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "struct \(identifier) ".write(to: &writer)
        let body = body()
        Braced {
            for element in body {
                element
            }
        }.write(to: &writer)
        Semicolon.write(to: &writer)
        Newline.write(to: &writer)
    }
}

public struct Attribute: Element {

    public let contents: String

    public init(contents: String) {
        self.contents = contents
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        "__attribute__(\(contents))".write(to: &writer)
    }
}

public struct ImportAttribute: Element {

    public let importName: String
    public let moduleName: String?

    public init(importName: String, moduleName: String? = nil) {
        self.importName = importName
        self.moduleName = moduleName
    }

    public func write<Stream: TextOutputStream>(to writer: inout Writer<Stream>) {
        var contents = "__import_name__(\"\(importName)\")"
        if let moduleName {
            contents.append(contentsOf: ", __module_name__(\"\(moduleName)\")")
        }
        Attribute(contents: contents).write(to: &writer)
    }
}

public struct Writer<Stream: TextOutputStream>: TextOutputStream {


    public let indentation: String
    public var currentIndentation: String = ""
    public var stream: Stream

    public init(
        stream: Stream = "",
        indentation: String = "    "
    ) {
        self.stream = stream
        self.indentation = indentation
    }

    public mutating func write(_ string: String) {
        stream.write(string)
    }
}

@resultBuilder
public struct CBuilder {
    public static func buildBlock(_ elements: [Element]...) -> [Element] {
        elements.flatMap { $0 }
    }

    public static func buildExpression(_ elements: [Element]) -> [Element] {
        elements
    }

    public static func buildExpression(_ element: Element) -> [Element] {
        [element]
    }

    public static func buildOptional(_ elements: [Element]?) -> [Element] {
        elements ?? []
    }

    public static func buildEither(first elements: [Element]) -> [Element] {
        elements
    }

    public static func buildEither(second elements: [Element]) -> [Element] {
        elements
    }

    public static func buildArray(_ elements: [[Element]]) -> [Element] {
        elements.flatMap { $0 }
    }
}

public func build(@CBuilder _ content: () -> [Element]) -> [Element] {
    content()
}
