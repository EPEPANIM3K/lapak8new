
@echo off
cd /d D:\lapak8new

mkdir lib\core\constants
mkdir lib\core\network
mkdir lib\core\router
mkdir lib\core\theme
mkdir lib\core\utils

mkdir lib\shared\widgets

mkdir lib\features\auth\providers
mkdir lib\features\auth\services
mkdir lib\features\auth\screens

mkdir lib\features\dashboard\screens
mkdir lib\features\dashboard\widgets

mkdir lib\features\facilities\models
mkdir lib\features\facilities\services
mkdir lib\features\facilities\screens
mkdir lib\features\facilities\widgets

mkdir lib\features\borrowings\models
mkdir lib\features\borrowings\services
mkdir lib\features\borrowings\screens
mkdir lib\features\borrowings\widgets

mkdir lib\features\qr\screens

mkdir lib\features\history\screens

mkdir lib\features\chat\models
mkdir lib\features\chat\services
mkdir lib\features\chat\screens

mkdir lib\features\rules\screens

mkdir lib\features\profile\screens
mkdir lib\features\profile\widgets

mkdir lib\features\admin\screens
mkdir lib\features\admin\widgets

type nul > lib\main.dart
type nul > lib\app.dart

type nul > lib\core\constants\app_colors.dart
type nul > lib\core\constants\app_text_styles.dart
type nul > lib\core\network\api_client.dart
type nul > lib\core\router\app_router.dart
type nul > lib\core\theme\app_theme.dart

type nul > lib\shared\widgets\custom_button.dart
type nul > lib\shared\widgets\custom_text_field.dart
type nul > lib\shared\widgets\confirm_dialog.dart
type nul > lib\shared\widgets\app_bottom_nav.dart
type nul > lib\shared\widgets\status_badge.dart
type nul > lib\shared\widgets\pagination_bar.dart
type nul > lib\shared\widgets\operating_hours_sheet.dart
type nul > lib\shared\widgets\empty_state.dart
type nul > lib\shared\widgets\loading_widget.dart

type nul > lib\features\auth\providers\auth_provider.dart
type nul > lib\features\auth\services\auth_service.dart
type nul > lib\features\auth\screens\splash_screen.dart
type nul > lib\features\auth\screens\welcome_screen.dart
type nul > lib\features\auth\screens\login_screen.dart

type nul > lib\features\dashboard\screens\dashboard_screen.dart
type nul > lib\features\dashboard\widgets\summary_card.dart

type nul > lib\features\facilities\models\facility.dart
type nul > lib\features\facilities\services\facility_service.dart
type nul > lib\features\facilities\screens\facility_list_screen.dart
type nul > lib\features\facilities\screens\facility_detail_screen.dart
type nul > lib\features\facilities\widgets\facility_card.dart

type nul > lib\features\borrowings\models\borrowing.dart
type nul > lib\features\borrowings\services\borrowing_service.dart
type nul > lib\features\borrowings\screens\borrowing_form_screen.dart
type nul > lib\features\borrowings\screens\my_borrowings_screen.dart
type nul > lib\features\borrowings\screens\borrowing_detail_screen.dart
type nul > lib\features\borrowings\widgets\date_selector.dart
type nul > lib\features\borrowings\widgets\time_slot_selector.dart
type nul > lib\features\borrowings\widgets\borrowing_card.dart

type nul > lib\features\qr\screens\qr_ticket_screen.dart
type nul > lib\features\qr\screens\qr_scanner_screen.dart

type nul > lib\features\history\screens\history_screen.dart

type nul > lib\features\chat\models\chat_message.dart
type nul > lib\features\chat\services\chat_service.dart
type nul > lib\features\chat\screens\chat_screen.dart

type nul > lib\features\rules\screens\rules_screen.dart

type nul > lib\features\profile\screens\profile_screen.dart
type nul > lib\features\profile\widgets\pic_help_sheet.dart

type nul > lib\features\admin\screens\admin_dashboard_screen.dart
type nul > lib\features\admin\screens\admin_borrowings_screen.dart
type nul > lib\features\admin\screens\manage_facilities_screen.dart
type nul > lib\features\admin\screens\facility_form_screen.dart
type nul > lib\features\admin\screens\manage_users_screen.dart
type nul > lib\features\admin\screens\user_form_screen.dart
type nul > lib\features\admin\screens\admin_profile_screen.dart

echo.
echo Struktur folder dan file SIPAT berhasil dibuat!
echo.
tree lib /F
pause
