import '../spec/enums.dart';
import '../spec/validation.dart';

/// JSON Schema for a beej spec file.
///
/// Emitted by `beej spec --schema`. This is the contract an agent writes
/// against: enum values come from the same tables the parser uses, so the
/// schema cannot describe an option beej does not accept.
String specJsonSchema() {
  String list(Iterable<String> values) => values.map((v) => '"$v"').join(', ');

  return '''
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "beej app spec",
  "description": "Configuration for `beej create --spec <file>`. Every property is optional; anything omitted takes its default.",
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "name": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9_]*\$",
      "description": "Dart package name, snake_case. Required unless passed as the first CLI argument."
    },
    "displayName": {
      "type": "string",
      "description": "Human-facing name. Defaults to the titleised name."
    },
    "description": {
      "type": "string",
      "description": "One line, used in pubspec.yaml and the store listing."
    },
    "org": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9_]*(\\\\.[a-z][a-z0-9_]*)+\$",
      "default": "com.popupbits",
      "description": "Reverse-DNS prefix. applicationId is <org>.<name>."
    },
    "platforms": {
      "default": "all",
      "description": "Target platforms.",
      "oneOf": [
        { "type": "string", "enum": ["all", "mobile"] },
        {
          "type": "array",
          "items": { "type": "string", "enum": [${list(TargetPlatform.values.map((v) => v.wire))}] },
          "minItems": 1,
          "uniqueItems": true
        }
      ]
    },
    "backend": {
      "default": "none",
      "description": "Backend wiring. The string form is shorthand for {kind: <value>}.",
      "oneOf": [
        { "type": "string", "enum": [${list(Backend.values.map((v) => v.wire))}] },
        {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "kind": { "type": "string", "enum": [${list(Backend.values.map((v) => v.wire))}] },
            "endpoint": { "type": "string", "format": "uri", "default": "https://cloud.appwrite.io/v1" },
            "projectId": { "type": "string", "description": "Defaults to name." },
            "databaseId": { "type": "string", "description": "Defaults to name." }
          }
        }
      ]
    },
    "router": {
      "type": "string",
      "enum": [${list(RouterKind.values.map((v) => v.wire))}],
      "default": "go_router",
      "description": "navigator is mobile-only; it is rejected when web is a target."
    },
    "nav": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "style": {
          "type": "string",
          "enum": [${list(NavStyle.values.map((v) => v.wire))}],
          "default": "tabs+drawer"
        },
        "tabs": {
          "type": "array",
          "minItems": 1,
          "maxItems": 5,
          "default": ["home"],
          "description": "Destinations. Settings is appended automatically, so \\"settings\\" is not allowed here.",
          "items": {
            "oneOf": [
              { "type": "string", "pattern": "^[a-z][a-z0-9_]*\$" },
              {
                "type": "object",
                "additionalProperties": false,
                "required": ["id"],
                "properties": {
                  "id": { "type": "string", "pattern": "^[a-z][a-z0-9_]*\$" },
                  "label": { "type": "string" },
                  "icon": { "type": "string", "description": "Icon constant name for the chosen icon set." }
                }
              }
            ]
          }
        }
      }
    },
    "database": {
      "type": "string",
      "enum": [${list(DatabaseKind.values.map((v) => v.wire))}],
      "default": "none"
    },
    "locales": {
      "type": "array",
      "items": { "type": "string", "enum": [${list(supportedLocales)}] },
      "default": ["en", "ne"],
      "minItems": 1,
      "uniqueItems": true,
      "description": "Must include en — it is the ARB template language."
    },
    "designSystem": {
      "type": "string",
      "enum": [${list(DesignSystem.values.map((v) => v.wire))}],
      "default": "local",
      "description": "popup_bits_design is currently rejected: it pins material_ui ^0.0.1, which cannot resolve alongside the 1.x line beej generates against."
    },
    "icons": {
      "type": "string",
      "enum": [${list(IconSet.values.map((v) => v.wire))}],
      "default": "picons"
    },
    "features": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "inAppUpdate": { "type": "boolean", "default": true, "description": "Play flexible in-app update. Android-only; no-ops elsewhere." },
        "notifications": { "type": "boolean", "default": false },
        "nepaliDates": { "type": "boolean", "default": false },
        "review": { "type": "boolean", "default": true }
      }
    },
    "about": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "privacyPolicyUrl": { "type": "string", "format": "uri", "description": "Defaults to https://www.popupbits.com/contact/<name>-privacy-policy" },
        "moreAppsUrl": { "type": "string", "format": "uri", "default": "https://www.popupbits.com/products" },
        "supportEmail": { "type": "string", "format": "email", "default": "info@popupbits.com" },
        "legalese": { "type": "string" }
      }
    },
    "tooling": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "fastlane": { "type": "boolean", "default": true },
        "githubWorkflow": { "type": "boolean", "default": true },
        "screenshots": { "type": "boolean", "default": true }
      }
    },
    "signing": {
      "type": "object",
      "additionalProperties": false,
      "description": "Omit entirely to skip keystore generation.",
      "properties": {
        "alias": { "type": "string", "description": "Defaults to name." },
        "storePassword": { "type": "string", "minLength": 6 },
        "keyPassword": { "type": "string", "minLength": 6, "description": "Defaults to storePassword." },
        "dname": { "type": "string", "description": "X.500 name passed to keytool." }
      }
    }
  }
}''';
}
