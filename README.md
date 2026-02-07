# KillingPart iOS

SwiftUI 기반 iOS 앱의 기본 구조를 다음 플로우로 초기 구성한 프로젝트입니다.

- Splash (video placeholder)
- Onboarding
- Login
- Main Tab (Home / Add)

## Environment

- Xcode: 16.4 (project tools version)
- Swift: 5.0
- UI Framework: SwiftUI
- Minimum iOS Deployment Target: 18.5
- Bundle ID: `com.KillingPoint.KillingPart`

## Folder Structure

```text
KillingPart/
├─ Views/
│  ├─ Screens/
│  │  ├─ Splash/
│  │  ├─ Onboarding/
│  │  ├─ Auth/
│  │  └─ Main/
│  └─ Components/
├─ ViewModels/
├─ Models/
├─ Services/
├─ Resources/
│  ├─ Assets/
│  ├─ Colors/
│  └─ Fonts/
├─ Extensions/
└─ Utils/
```

## App Flow

1. 앱 시작 시 `SplashView` 노출 (영상 영역 placeholder 포함)
2. 자동으로 `OnboardingView` 이동
3. `LoginView`에서 로그인 성공 시 메인 화면 진입
4. `MainTabView`에서 `홈`, `추가` 2개 탭 제공

## Shared Color Palette

요청하신 메인 컬러 `#CEFF43`를 `primary600`으로 정의했고, 공용 팔레트로 `primary100~600`을 제공합니다.

- `primary100`: `#F8FFE8`
- `primary200`: `#F0FFD0`
- `primary300`: `#E8FFB8`
- `primary400`: `#DFFF90`
- `primary500`: `#D6FF69`
- `primary600`: `#CEFF43`

정의 위치:

- `KillingPart/Resources/Colors/AppColors.swift`
- `KillingPart/Extensions/Color+Hex.swift`

## Notes

- Splash 영상은 `SplashView`의 placeholder 영역에 `AVPlayer`를 연결하면 바로 확장 가능합니다.
- 현재 로그인은 `Services/AuthenticationService.swift`의 목업 로직(이메일/비밀번호 비어있지 않음)으로 동작합니다.
