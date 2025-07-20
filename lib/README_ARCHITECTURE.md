# Clean Architecture Implementation

This project now follows Clean Architecture principles with clear separation of concerns.

## 📁 Project Structure

```
lib/
├── core/                          # Core utilities and constants
│   ├── constants/
│   │   └── app_constants.dart     # App-wide constants
│   └── utils/
│       └── ui_helpers.dart        # UI utility functions
│
├── domain/                        # Business Logic Layer
│   ├── entities/                  # Pure business objects
│   │   ├── user.dart
│   │   └── highlight.dart
│   ├── repositories/              # Repository interfaces
│   │   ├── user_repository.dart
│   │   └── auth_repository.dart
│   └── usecases/                  # Business use cases
│       ├── auth/
│       │   ├── verify_phone_number.dart
│       │   ├── sign_in_with_credential.dart
│       │   └── get_current_user.dart
│       └── user/
│           ├── create_user.dart
│           ├── get_user_stream.dart
│           └── update_tokens_used.dart
│
├── data/                          # Data Layer
│   ├── models/                    # Data models with JSON conversion
│   │   ├── user_model.dart
│   │   └── highlight_model.dart
│   ├── datasources/               # External data sources
│   │   ├── firestore_datasource.dart
│   │   └── firebase_auth_datasource.dart
│   └── repositories/              # Repository implementations
│       ├── user_repository_impl.dart
│       └── auth_repository_impl.dart
│
├── presentation/                  # UI Layer
│   ├── pages/                     # Full screen pages
│   │   ├── auth/
│   │   │   └── auth_check_page.dart
│   │   └── onboarding/
│   │       └── onboarding_page.dart
│   └── widgets/                   # Reusable UI components
│       ├── common/
│       │   ├── custom_button.dart
│       │   └── custom_text_field.dart
│       └── auth/
│           └── phone_input_widget.dart
│
├── main.dart                      # App entry point
├── home_screen.dart              # ✅ Refactored to use clean architecture
└── phone_auth_screen.dart        # ✅ Updated to use clean architecture
```

## 🏗️ Architecture Layers

### 1. **Domain Layer** (Business Logic)

- **Entities**: Pure business objects without any external dependencies
- **Use Cases**: Application-specific business rules
- **Repository Interfaces**: Abstract contracts for data access

**Key Principles:**

- No dependencies on external frameworks
- Contains the core business logic
- Defines interfaces for data access

### 2. **Data Layer** (Data Access)

- **Models**: Data representations with JSON/Map conversion
- **Data Sources**: Direct communication with external APIs/databases
- **Repository Implementations**: Concrete implementations of domain interfaces

**Key Principles:**

- Handles all external data communication
- Converts external data to domain entities
- Implements repository interfaces from domain layer

### 3. **Presentation Layer** (UI)

- **Pages**: Full screen widgets representing app screens
- **Widgets**: Reusable UI components
- **State Management**: UI state and user interactions

**Key Principles:**

- Contains only UI logic
- Depends on domain layer for business operations
- No direct dependency on data layer

### 4. **Core Layer** (Shared)

- **Constants**: App-wide constants and configuration
- **Utils**: Shared utility functions and helpers

## 🔄 Data Flow

```
UI → Use Cases → Repository Interface → Repository Implementation → Data Source → External API/Database
```

## ✅ Benefits Achieved

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Testability**: Easy to unit test business logic independently
3. **Maintainability**: Changes in one layer don't affect others
4. **Scalability**: Easy to add new features following the same pattern
5. **Independence**: Business logic is independent of frameworks and UI

## 🛠️ Dependencies

- **Domain Layer**: No external dependencies (pure Dart)
- **Data Layer**: Depends on Domain layer and external packages (Firebase, etc.)
- **Presentation Layer**: Depends on Domain layer and Flutter

## 📝 TODO Items

1. ✅ ~~Refactor `home_screen.dart` to follow clean architecture~~ **COMPLETED**
2. Implement dependency injection (consider using GetIt or Riverpod)
3. Add proper error handling with Result/Either types
4. Implement state management (BLoC, Riverpod, or Provider)
5. Add unit tests for use cases and repositories
6. Create widget tests for UI components
7. Move `BuyToken` widget to separate page in presentation layer
8. Add error boundaries and proper exception handling

## 🚀 Getting Started

To add a new feature:

1. **Define the entity** in `domain/entities/`
2. **Create use cases** in `domain/usecases/`
3. **Add repository interface** in `domain/repositories/`
4. **Implement data model** in `data/models/`
5. **Create data source** in `data/datasources/`
6. **Implement repository** in `data/repositories/`
7. **Build UI components** in `presentation/`

This structure ensures your code remains clean, testable, and maintainable as your app grows.
