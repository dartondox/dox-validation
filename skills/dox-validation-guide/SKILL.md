---
name: dox-validation-guide
description: Use when you check request input in a Dox (Dart) app. Covers @Dto classes and rule annotations, optional and Maybe fields, custom messages, custom rules, fluent v.object schemas, database rules, and ValidationFlags.
---

# Dox validation

`dox_validation` checks input and gives typed Dart objects. It returns all errors at once.
It has two parts:

1. DTOs: a class with `@Dto()` and rule annotations. A generator writes the checks. Use this for almost everything.
2. Fluent schemas: `v.object(...)`. Use them only when the shape is known at runtime.

For routes and controllers, see the `dox-core-guide` skill.

## Setup

In a Dox app you add nothing. `dox_core` exports `dox_validation`: `import 'package:dox_core/dox_core.dart';`.
`@Unique` and `@Exists` come from `dox_orm`.

1. `dox make:dto CreateUser` writes `lib/app/dtos/create_user/create_user.dto.dart`.
2. Run the generator: `dox build_runner:build` (or `dart run build_runner build`). Run it after every DTO change.
3. Give the generated list to the app, once:

```dart
// lib/config/app.dart
import 'package:my_app/generated/dtos.g.dart';

AppConfig appConfig = AppConfig(
  dtos: dtos,
  // ...
);
```

Without `dtos`, the server stops at start with an error. Never edit `*.g.dart` files.

## Recipes

### 1. A DTO

```dart
import 'package:dox_core/dox_core.dart';

part 'create_user.dto.g.dart';

@Dto()
class CreateUser {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  final int? age;

  const CreateUser({required this.name, required this.email, this.age});

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

Ask for the DTO as a controller parameter. Dox checks the request first. Bad input gets `422` and the method does not run.

```dart
Future<Map<String, dynamic>> store(CreateUser body) async {
  return <String, dynamic>{'name': body.name};
}

Future<User> update(DoxRequest req, int id, UpdateUser body) async { ... }
```

Or check by hand: `CreateUser data = await req.validate<CreateUser>();`.

### 2. Required and optional

The Dart type decides. You write no `required`.

| Field | Key missing | Value `null` |
| --- | --- | --- |
| `final String name;` | error `required` | error `required` |
| `final int? age;` | `null` | `null` |
| `final Role role;` with `this.role = Role.user` | `Role.user` | error `required` |

- Rules on an optional field run only when it has a value. A default is used only when the key is missing.
- An empty string counts as missing. `@AllowEmpty()` keeps `""`.
- Spaces are kept unless the field has `@Trim()`. `@Dto(trim: true)` trims every text field.
- `@OrDefault()` turns a bad value into the default, with no error. The field needs a default, a nullable type or `Maybe`.
- For PATCH, use `Maybe<T>` to tell "missing" from `null`:

```dart
@Length(max: 500)
final Maybe<String?> bio; // default: const Maybe.missing()

if (body.bio.isPresent) {
  user.bio = body.bio.value; // may be null: the client cleared it
}
```

### 3. Where the data comes from

- `GET`, `HEAD`, `DELETE` read the query. Other methods read the body. Dox never mixes them.
- Force it: `@Dto(source: Source.query)`, or `req.validate<T>(source: Source.query)`.
- Path params are not in a DTO. Take them as controller parameters, like `int id`.
- The key of a field is its snake_case name (`firstName` reads `first_name`). Change it with `@Name('emailAddress')` or `@Dto(keyCase: KeyCase.field)`.
- Unknown keys are dropped. `@Dto(strict: true)` makes them an error.
- JSON is strict: `"18"` is not an `int`. `@Dto(coerce: true)` accepts text for numbers and bools.
- Types: `String`, `int`, `double`, `num`, `bool`, `DateTime` (ISO 8601), enums (by name), `RequestFile`, nested `@Dto` classes, `List<T>`, `Map<String, T>`.

### 4. Rules

Annotations run from top to bottom. The first failed rule gives the error.

| Kind | Annotations |
| --- | --- |
| Text | `@Length`, `@MinLength`, `@MaxLength`, `@Email`, `@Url`, `@Uuid`, `@Ulid`, `@Ip`, `@Regex`, `@In`, `@NotIn`, `@StartsWith`, `@EndsWith`, `@Alpha`, `@AlphaNumeric`, `@AlphaDash` |
| Change text | `@Trim`, `@Lowercase`, `@Uppercase`, `@AllowEmpty` |
| Numbers | `@Min`, `@Max`, `@Range`, `@Positive`, `@GreaterThan`, `@LessThan` |
| Lists | `@MinItems`, `@MaxItems`, `@UniqueItems` |
| Dates | `@After`, `@Before`, `@AfterOrEqual`, `@BeforeOrEqual` |
| Other fields | `@Same`, `@Confirmed`, `@Different`, `@GreaterThanField`, `@LessThanField`, `@ProhibitedIf` |
| Present or missing | `@RequiredIf`, `@RequiredUnless`, `@RequiredWith`, `@RequiredWithout`, `@RequiredWithoutAll`, `@Filled`, `@Present`, `@Prohibited`, `@Accepted`, `@Declined` |
| Skip a field | `@ExcludeIf`, `@ExcludeUnless` |
| Files | `@MaxSize`, `@MinSize`, `@Mimes`, `@MimeTypes`, `@Image`, `@Dimensions` |
| Database | `@Unique`, `@Exists` |

Every rule has an optional `message:`. A rule on a `List<String>` checks each item.
The full list with error codes is in the docs: https://dartondox.dev/llms-full.txt.

### 5. Nested objects, lists, files

```dart
@Dto()
class CreateOrder {
  final Address address; // a @Dto class

  @MinItems(1)
  final List<OrderItem> items;

  @Image()
  @MaxSize('2MB')
  final RequestFile? photo;

  const CreateOrder({required this.address, required this.items, this.photo});

  static const DtoSchema<CreateOrder> schema = $CreateOrderDto;
}
```

A nested error has a path key, like `items.1.quantity`. Files come from `multipart/form-data`. Dox checks the real type from the first bytes.

### 6. Checks across fields: `validate()`

Add a method. Dox calls it after all field rules passed. It may be `async`.

```dart
void validate(DtoErrors errors) {
  if (password != passwordConfirmation) {
    errors.add('password_confirmation', 'The passwords do not match');
  }
}
```

Use the key `_root` for an error about the whole body. Do not throw for bad input. Add an error.

### 7. Database rules

```dart
import 'package:dox_orm/dox_orm.dart';

@Unique('users', column: 'email')
final String email;

@Exists('teams') // column defaults to id
final int teamId;

// PUT /users/{id}: skip the row being updated
@Unique('users', column: 'email', ignoreParam: 'id')
final String email;
```

They run last. A `PresenceVerifier` is set by `dox_orm` when the database starts.

### 8. Custom messages

First one wins:

1. On the rule: `@Email(message: 'Please check your email')`.
2. On the DTO: `@Dto(messages: <String, String>{'email.required': 'We need your email', 'tags.*.required': '...'})`.
3. For the whole app, with a `MessageResolver` (for other languages):

```dart
class AppMessages extends MessageResolver {
  static const Map<String, Map<String, String>> _texts = <String, Map<String, String>>{
    'th': <String, String>{'required': 'กรุณากรอก {field}'},
  };

  @override
  String resolve(MessageRequest request) {
    String? template = _texts[request.locale]?[request.code];
    if (template == null) {
      return super.resolve(request);
    }
    return format(template, request.params);
  }
}

AppConfig appConfig = AppConfig(validationMessages: AppMessages());
```

Placeholders: `{field}`, `{value}`, and rule values like `{min}` and `{max}`.
Names for `{field}`: `@Dto(attributes: <String, String>{'first_name': 'first name'})`.

The `422` answer is one message per field: `{"email": "The email is not a valid email", "items.1.quantity": "..."}`.
For another shape, read `error.issues` (each has `dottedPath`, `code`, `message`, `params`) in your `ExceptionHandler`.

### 9. Custom rule

```dart
class Slug extends Rule<String> {
  const Slug({super.message});

  @override
  String get name => 'slug'; // the error code

  @override
  String get defaultMessage => 'The {field} must be a slug';

  @override
  bool check(String value, RuleContext context) => _pattern.hasMatch(value);

  static final RegExp _pattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
}

@Slug()
final String slug;
```

- A rule with values: add `final` fields and override `params`. They become placeholders.
- `context.lookup('other.key')` and `context.sibling('key')` read other input.
- A rule that needs the database: extend `AsyncRule<T>` and write `checkAsync`.
- The same class works in a fluent schema: `v.string().use(const Slug())`.

### 10. Fluent schemas (runtime shape)

```dart
final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
  'role': v.enumOf<String>(<String>['admin', 'user']).defaultTo('user'),
  'tags': v.list(v.string()).max(5),
});

Map<String, dynamic> data = createUser.parse(input);          // throws ValidationException
ParseResult<Map<String, dynamic>> r = createUser.safeParse(input);
Map<String, dynamic> body = await req.validateSchema(createUser); // in a controller
```

- Here a key is required unless you add `optional()`. `""` is a value. Text is not converted unless you use `v.coerce`.
- On every schema: `optional()`, `nullable()`, `nullish()`, `defaultTo(x)`, `transform`, `refine`, `refineAsync`, `bail()`, `requiredIf`, `confirmed()`.
- `exists` and `unique` and `refineAsync` are async. Use `parseAsync()` or `safeParseAsync()`. `parse()` throws `StateError` on async rules.
- A whole-object check: `.refine((Map<String, dynamic> d) => d['a'] == d['b'], message: '...', path: <Object>['b'])`.
- A DTO schema works inside a fluent schema: `'address': Address.schema`.

### 11. Test a DTO

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(<String, dynamic>{
  'name': 'A',
  'email': 'bad',
});
expect(result.success, isFalse);
expect(result.errors['email'], 'The email is not a valid email');
```

`validateMap` returns the object or throws. `safeValidateMap` never throws for bad input.
`ParseResult` has `success`, `value`, `errors` (first message per field), `fieldErrors` and `issues`.

## Flags

Opt-in behavior, all off by default. Set `Validator.flags` in a `DoxProvider` `setup()`, so every isolate runs it:

```dart
class ValidationProvider extends DoxProvider {
  @override
  void setup() {
    Validator.flags = const ValidationFlags(dtoAllErrors: true, unicodeAlpha: true);
    // or: const ValidationFlags.all()
  }
}
```

| Flag | Effect |
| --- | --- |
| `emptyStringsToNull` | Fluent schemas read `""` as `null`. |
| `unicodeAlpha` | `alpha`, `alphaNumeric`, `alphaDash` accept Unicode letters. |
| `shortInMessage` | The `in` message does not list the allowed values. |
| `dtoAllErrors` | A DTO reports all field errors at once. |
| `dtoRejectEmptyList` | A required `List` field fails on `[]`. |
| `dtoMaybeRejectsEmpty` | A `Maybe<T>` field fails `required` on an empty value. |
| `laravelMessageKeys` | Message keys may use the alternate rule names, like `name.min`. |

The three DTO flags need a fresh `build_runner` run.

## Gotchas

- Forgot `dtos: dtos` in `AppConfig`, or forgot to run the generator: the server stops at start.
- Missing `part 'x.dto.g.dart';` or `static const DtoSchema<X> schema = $XDto;` breaks the build.
- `fromMap` builds a DTO with no checks. Use it only for trusted data.
- `Validator.flags` is per isolate. Set it in a provider.
- In tests, prefer `safeValidateMap`. Both `ValidationException` types answer `422` in a controller.
