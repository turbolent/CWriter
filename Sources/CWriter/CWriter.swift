
public indirect enum Type {
    case Nominal(String)
    case Pointer(Type)
    case Struct(String)

    public func write<Stream: TextOutputStream>(to stream: inout Stream) {
        switch self {
            case let .Nominal(name):
                name.write(to: &stream)
            case let .Pointer(type):
                type.write(to: &stream)
                "*".write(to: &stream)
            case let .Struct(name):
                "struct \(name)".write(to: &stream)
        }
    }
}

public protocol Element {

    func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>)
}

public struct Indentation: Element {

    public init() {}

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        writer.currentIndentation.write(to: &writer)
    }
}

public struct Raw: Element {

    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        Indentation().write(to: &writer)
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        writer.currentIndentation.append(writer.indentation)
        for Element in body() {
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        "{".write(to: &writer)
        Indented(body: body).write(to: &writer)
        "}".write(to: &writer)
    }
}

public struct Parameter: Element {
    public let name: String?
    public let type: Type

    public init(name: String? = nil, type: Type) {
        self.name = name
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        type.write(to: &writer.stream)
        if let name {
            " \(name)".write(to: &writer)
        }
    }
}

public struct Field: Element {
    public let name: String
    public let type: Type

    public init(name: String, type: Type) {
        self.name = name
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        type.write(to: &writer)
        " \(name)".write(to: &writer)
        Semicolon.write(to: &writer)
        Newline.write(to: &writer)
    }
}

public struct Function: Element {

    public let returnType: Type
    public let name: String
    public let parameters: [Parameter]
    public let body: Body

    public init(
        returnType: Type,
        name: String,
        parameters: [Parameter] = [],
        @CBuilder body: @escaping Body = { [ ] }
    ) {
        self.returnType = returnType
        self.name = name
        self.parameters = parameters
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        Indentation().write(to: &writer)
        returnType.write(to: &writer)
        " \(name)".write(to: &writer)
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
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

    public let name: String
    public let type: Type

    public init(name: String, type: Type) {
        self.name = name
        self.type = type
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        Indentation().write(to: &writer)
        "typedef ".write(to: &writer)
        type.write(to: &writer)
        " \(name)".write(to: &writer)
        Semicolon.write(to: &writer)
        Newline.write(to: &writer)
    }
}

public struct Struct: Element {

    public let name: String
    public let body: Body

    public init(
        name: String,
        @CBuilder body: @escaping Body = { [ ] }
    ) {
        self.name = name
        self.body = body
    }

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        Indentation().write(to: &writer)
        "struct \(name) ".write(to: &writer)
        let body = body()
        Braced {
            if !body.isEmpty {
                Newline
            }
            for element in body {
                Indentation()
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
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

    public func write<Stream: TextOutputStream>(to writer: inout CWriter<Stream>) {
        var contents = "__import_name__(\"\(importName)\")"
        if let moduleName {
            contents.append(contentsOf: ", __module_name__(\"\(moduleName)\")")
        }
        Attribute(contents: contents).write(to: &writer)
    }
}

public struct CWriter<Stream: TextOutputStream>: TextOutputStream {


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
