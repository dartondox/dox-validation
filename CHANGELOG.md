## 3.2.0

- Ships an AI agent skill (dox-validation-guide). Install it in your app with `dart run skills@ get`.
- New: `ValidationFlags`, opt-in behaviors that are all off by default. Set them with `Validator.flags = const ValidationFlags(...)`. `ValidationFlags.all()` turns every one on. Set them in each isolate, like in a provider's `setup()`.
  - `emptyStringsToNull`: fluent schemas turn each `""` in the input into `null` before they check it, also in nested maps and lists. So `""` fails a required field.
  - `unicodeAlpha`: `alpha`, `alphaNumeric` and `alphaDash` accept Unicode letters and marks (like `José`), and Unicode digits where digits are allowed. It works for fluent schemas and DTOs.
  - `shortInMessage`: the default `in` message is `The selected {field} is invalid`, with no list of values.
- New: three opt-in `ValidationFlags` for DTOs. Each one needs DTO code from a dox_builder that knows it. Code from an older dox_builder works as before.
  - `dtoAllErrors`: a DTO runs the rules of each field that has the right type, also when another field is missing or has the wrong type. So one request gets all its errors at once.
  - `dtoRejectEmptyList`: a required `List` field fails `required` on `[]`.
  - `dtoMaybeRejectsEmpty`: a `Maybe<T>` field (with `T` not nullable) fails `required` when the key is sent with an empty value, like `""`. A missing key still gives `Maybe.missing()`.
- New: `DtoState.allErrors`, `DtoState.emptyList()` and `DtoState.sentEmpty()`, used by the generated code.
- New: `AlphaRule` and `DefaultMessages.inListShort`. `Patterns.alpha`, `Patterns.alphaDash` and `Patterns.alphaNumeric` are now getters that follow `Validator.flags`.
- Faster: a DTO with no `@RequiredIf` or `@RequiredWith` (and no nested DTO with them) no longer keeps each converted value. Needs a dox_builder that knows it. Code from an older dox_builder works as before.
- New: `DtoSchema.usesRequiredWhen` and `DtoState.keepValues`, used by the generated code. `DtoState(keepValues: true)` is the default, so nothing changes for code that makes a `DtoState`.
- New: `@Dto(trim: true)` trims every text field of a DTO, like Laravel's `TrimStrings`. So `"   "` counts as missing. Off by default. Needs a dox_builder that knows it.
- New: `@Dto(coerce: true)` lets a JSON body send `"18"`, `"4.5"` and `"true"` (and `1` / `0` for a bool), like a form. Off by default: JSON stays strict. Needs a dox_builder that knows it.
- New: names for `{field}` in messages, like Laravel's custom attributes. `MessageResolver(attributes: {...})`, `MessageResolver.setAttributes()` and `MessageResolver.attributeName()` for the whole app or one call, and `@Dto(attributes: {...})` for one DTO. `{other}` and `{others}` show the names of the other keys too. With no names, the messages do not change.
- New: the opt-in flag `ValidationFlags.laravelMessageKeys`. With it on, a custom message key can use the Laravel rule name, like `name.min` for the `min_length` error, in `@Dto(messages:)` and in a `MessageResolver`. The Dox code wins at each step of the lookup. The issue code does not change. See `IssueCodes.laravel`. Off by default: only the Dox codes match.
- New: `@After` and `@Before` take `'today'`, `'tomorrow'`, `'yesterday'` and the key of another `DateTime` field. New `@AfterOrEqual` and `@BeforeOrEqual`. Needs a dox_builder that knows them.
- New Laravel rules for DTOs and fluent schemas: `@RequiredUnless` / `.requiredUnless()`, `@RequiredWithout` / `.requiredWithout()`, `@RequiredWithoutAll` / `.requiredWithoutAll()`, `@Filled` / `.filled()`, `@Present` / `.present()`, `@Prohibited` / `.prohibited()` (like Laravel: a sent `null`, `[]`, `0` or `false` fails, blank text passes), `@ProhibitedIf` / `.prohibitedIf()` (like Laravel: when the condition matches, `null`, blank text and an empty list or map pass, `0` and `false` fail), `@Accepted` / `.accepted()`, `@Declined` / `.declined()`, `@Different` / `.different()`, `@Ulid` / `.ulid()`, and `@GreaterThanField`, `@GreaterThanOrEqualField`, `@LessThanField`, `@LessThanOrEqualField` / `.gtField()`, `.gteField()`, `.ltField()`, `.lteField()`.
- New: `@ExcludeIf` and `@ExcludeUnless` for DTOs. A skipped field is not checked and gets its missing value. Needs a dox_builder that knows them.
- New: `.bail()` for fluent schemas, like Laravel `bail`. The first failed rule of the schema stops its other rules, also async rules. It counts for the rules of that schema only: a wrapper like `.optional()`, the fields of an object and the items of a list keep their own setting. So call `.bail()` before `.optional()`: after it, it does nothing for the inner rules. New `Schema.bails`.
- New: `.excludeIf(other, value)` and `.excludeUnless(other, value)` for a field of `v.object()`, like Laravel `exclude_if` and `exclude_unless`. When the condition matches, the field is not checked and its key is left out of the output, also with `.defaultTo()`. They read the raw value of the other key (a key of the same object, not a dotted path) and match like `@ExcludeIf` and `@ExcludeUnless`. The cross-field rules of other fields still read the raw value of a skipped field. The JSON Schema does not list the field as required. Outside an object they do nothing. New `ExcludeSchema` and `ExcludeWhen`, the base of `ExcludeIf` and `ExcludeUnless`.
- New: `RequiredWhen.appliesToField()`, `RequiredWhen.checksValues`, `ParseState.attributeName()`, `RequiredWhen.matches()`, `RequiredWhen.listOf()`, `DtoState.attributes()`, the `coerce:` parameter of `DtoState.integer()`, `decimal()`, `number()` and `boolean()`, and the `trim:` parameter of `DtoState.read()`, used by the generated code. New issue codes and default messages for the new rules.

## 3.1.2

- Docs: the dartdoc of `@OrDefault` says that errors from `@Unique`, `@Exists` and `validate()` are not dropped.
- New: `@Describe('...')` on a DTO field. It sets `description` in the JSON Schema of the field. It does not change the checks. Needs a dox_builder that knows it.

## 3.1.1

- New: `@Dto(emptyStringsToNull: true)` reads `""` as `null`, like Laravel's `ConvertEmptyStringsToNull`. So `{"note": ""}` clears a `Maybe<String?>` field instead of counting as missing. Needs a dox_builder that knows it.
- New: `@OrDefault()` on a DTO field: a bad value (a type error or a failed rule) gives the default of the field, or `null`, not an error. For query strings like `?page=abc`. Needs a dox_builder that knows it.
- New: `hexColor()` / `@HexColor()`: `#` and 6 hex digits, like `#1a2b3c`. `short: true` also takes `#abc`.
- New: `DtoState.read(..., emptyToNull: true)` and `DtoState.dropIssuesAfter(count)`, used by the generated code.

## 3.1.0

- Break: `IpRule` is no longer a `RegexRule`, so `IpRule().pattern` is gone.
- `v.string().ip()` now accepts IPv6, like `@Ip`. Its JSON Schema is now `anyOf` `ipv4` and `ipv6` (was `format: ipv4`).
- `email()` now accepts `+` and `'` before the `@` (like `ann+tag@x.com`), the same symbols as HTML5.
- `alphaDash()` now allows digits (`post-123`), like Laravel `alpha_dash`. The message text changed too.
- New Laravel-style rules. Each works in fluent schemas and as a DTO annotation, unless noted:
  - `same('other')` / `@Same('other')`: the value must equal another key in the same object.
  - `confirmed()` / `@Confirmed()`: `<field>_confirmation` must have the same value.
  - `same` and `confirmed` compare the raw input of both keys, like Laravel. Text matches a number or a bool by text, both ways.
  - `.optional().requiredIf('type', 'company')` / `@RequiredIf('type', 'company')`: required when another key has a value. An enum value matches its name. Missing means: not there, `null`, blank text or an empty list.
  - `.optional().requiredWith(['phone'])` / `@RequiredWith(['phone'])`: required when another key is present.
  - `.nullable()` after `requiredIf` or `requiredWith` keeps the check. Before, `null` passed even when the rule applied. It looks through every wrapper, so `.transform(...).nullable()`, `.defaultTo(...).nullable()` and `.nullable().nullable()` keep the check too.
  - `requiredIf` and `requiredWith` read the other key after its own conversion, like `trim()` and `toLowerCase()`. This is the value the app gets. Before, they read the raw input, so `type: ' Company '` did not make `vat` required, but the app got `type == 'company'`. When the other key fails its own check, the raw input is still used. In a fluent object, the keys with these rules are checked last, so the order of the keys does not matter. The output and the issues still come in the order of the shape. An object without these rules does no extra work. In a DTO, the other field must come before the field with the rule, because the generated code checks the fields in order.
  - `json()` / `@Json()`: the text must be valid JSON.
  - `digits(6)` / `@Digits(6)` and `digitsBetween(4, 6)` / `@DigitsBetween(4, 6)`: only digits, with this length.
  - `between(1, 10)` on `v.int()` and `v.num()`. DTOs already have `@Range(1, 10)`.
  - `dateFormat('Y-m-d')` / `@DateFormatted('Y-m-d')`: a real date in this format. It knows the PHP `date()` letters, like `M`, `D`, `A` and `U`. Another letter throws an `ArgumentError`; put `\` before it to use it as text. Like Laravel, `j`, `n`, `g`, `G`, `z` and `U` take no leading zero.
  - `password(min: 8, letters: true, mixedCase: true, numbers: true, symbols: true)` / `@Password(...)`: a strong password. It does not check leaked passwords.
  - `exists('teams')` and `unique('users', column: 'email')` on `v.string()`, `v.int()` and `v.num()`. They need `parseAsync`. `unique` needs `column:`; it never uses the input key. The database decides what matches, also for a list, so on MySQL `TAKEN@dox.dev` is taken when `taken@dox.dev` is there. A DTO `List` field (and `failedItems` of the rules) is one query for the whole list: an `exists` item passes only when its exact text is found, and a `unique` item fails when a found row has its exact text. When a found row matches no item by its text (MySQL ignores case and trailing spaces), one query can not tell which item it was, so every item fails (the safe side). `v.list(v.string().exists(...))` still checks each item alone, so the database decides for each one. Limit long lists with `.max(n)` / `@MaxItems`. They ask a `PresenceVerifier`, which `dox_orm` sets when the database starts. Table and column names are checked when the schema is built: the same plain names the dox_orm query builder takes, like `2fa_codes` or `public.users`. DTOs keep `@Exists` and `@Unique` from `dox_orm`.
- `@RequiredIf` and `@RequiredWith` need `dox_builder` 3.1.0 or newer.
- `RuleContext.sibling('key')` reads another key of the same object.
- `@Dto(messages:)` matches the dotted path first, like Laravel: `tags.*.required` for list items. The outer DTO can name `address.city.required` for a field of a nested DTO. A message in the nested DTO itself (`city.required`) wins over it. Then the last key (`city.required`), then the code (`required`), as before.
- New file rules, like Laravel:
  - `v.file().maxSize(bytes)` and `minSize(bytes)`, and `@MinSize('10KB')`. Laravel counts KB; the fluent rules count bytes. The message shows a short size, like `2MB`.
  - `v.file().mimes([...])`, the same check as `@Mimes`.
  - `v.file().mimeTypes(['image/png', 'image/*'])` and `@MimeTypes`. The MIME type is checked against the real file bytes, not the content type the client sent. SVG is never part of `image/*`.
  - `v.file().dimensions(minWidth:, maxWidth:, minHeight:, maxHeight:, width:, height:, ratio:)` and `@Dimensions`. It reads only the image header of PNG, GIF, WebP and JPEG files. Other files, and broken or cut short headers, fail.
- `ImageSize.read(head)` gives the width and height from the first bytes of an image. `FileTypes.matchesMimeTypes` and `FileTypes.extensionsOf` turn MIME types into checked file types.
- `FileInput.head` may hold more than `FileTypes.headSize` bytes. A JPEG keeps its size after the photo metadata, so `dimensions` needs more bytes for it (see `ImageSize.jpegHeadSize`).
- `@MinSize`, `@MimeTypes` and `@Dimensions` need dox_builder 3.1.0 or newer. An older dox_builder skips them without an error, so they check nothing.
- `dimensions` on a JPEG needs dox_core 3.1.0 or newer. With an older dox_core, `RequestFile.head` has only 32 bytes, so every JPEG fails `dimensions`.
- `ip()` and `@Ip` now reject IPv4 addresses with leading zeros, like `01.1.1.1`. Laravel does the same. Some tools read `010` as octal (8), so these addresses are not what they look like.

## 3.0.0

- The first stable release.
- The package now lives in its own repo: [dartondox/dox-validation](https://github.com/dartondox/dox-validation). Nothing changes for users: same package name, same API.

## 3.0.0-rc.1

- Version bump only, to match the other packages.

## 3.0.0-alpha.17

- Version bump only, to match the other packages.

## 3.0.0-alpha.16

- Version bump only, to match the other packages.

## 3.0.0-alpha.15

- Version bump only, to match the other packages.

## 3.0.0-alpha.14

- Version bump only, to match the other packages.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Version bump only, to match the other packages.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Fix: `FileTypes.sniff` read any data that starts with `BM` as `bmp`, like the text "BMW...". Now it also checks the BMP header size at byte 14 (12, 40, 52, 56, 64, 108 or 124).

## 3.0.0-alpha.7

- Perf: object, list, map and union schemas work out `isAsync` once and keep the answer. Before, the whole schema tree was walked on every `validateSchema` call.
- `url()` now allows only `http` and `https` links. Pass `schemes` to allow others.
- File type checks now also need the file name extension to fit the bytes. A `.html` file with GIF bytes no longer passes `@Image`. Only another known type (like `.png` with GIF bytes) or a type the browser runs (`html`, `htm`, `xhtml`, `svg`, `xml`, `js`, `mjs`) is refused. A file with no or an unknown extension (like a canvas upload named `blob`) passes when the bytes match.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- A JSON body that is not an object now says `The request body must be a JSON object.` (key `_root`). Change it with the message key `_root.object`.
- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- New: DTOs. A class with `@Dto()` and rule annotations (`@Length`, `@Email`, `@Min`, `@Regex`, `@MaxSize`, ...). `dox_builder` writes a `const DtoSchema<T>` with the checks, a converter and the JSON Schema. See the Validation guide.
- New: `DtoSchema<T>` with `validateMap`, `safeValidateMap`, `fromMap`, `toMap` and `toJsonSchema`. It is also a `Schema<T>`.
- New: `Maybe<T>` knows a missing key from `null`. `DtoErrors` for checks across fields in `validate()`.
- New: `FileTypes` finds the real type of a file from its first bytes. `@Image()` and `v.file().image()` do not allow `svg`.
- New: `MessageRequest.locale`, `ParseState.params`. A message set on a rule is used as it is; the resolver only fills its placeholders.
- `Rule` has a `const` constructor and a `final` `message`, so a rule class works as an annotation. `AsyncRule.failedItems()` checks a list in one call.
- `FileInput` has `length` and `head` (the first bytes).
- `Schema` has a `const` constructor. The fluent schemas extend `BaseSchema`.
- Text length messages say "characters".
- Breaking: removed `v.fromRules()`, `v.registerRule()`, `RuleRegistry`, `RuleDefinition`, `CallbackRule` and all rule strings. Use a DTO, or a `Rule<T>` class.


## 3.0.0-alpha.1

- First release of `dox_validation`.
- Fluent schema builder: string, int, num, bool, date, enum, literal, list, object, map, union, any, file.
- `optional`, `nullable`, `nullish`, `defaultTo`, `transform`, `refine`, `superRefine`, async refinements.
- Coercion with `v.coerce` for query strings and form data.
- `parse`, `safeParse`, `parseAsync`, `safeParseAsync` with issue paths.
- Standard Schema interface (`StandardSchema`).
- JSON Schema (draft 2020-12 / OpenAPI 3.1) export with `toJsonSchema()`.
- Custom `Rule` classes and a global `MessageResolver`.
- Laravel style string rules with `v.fromRules()`.
