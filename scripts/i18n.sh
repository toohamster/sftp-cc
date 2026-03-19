#!/bin/bash
# i18n.sh — Internationalization support for sftp-cc-toomaster
# Multi-language support: English (en), Chinese (zh), and Japanese (ja)
# Default language: English
#
# Usage: Source this file in your script, then use $MSG_XXX variables
# Example:
#   source "$SCRIPT_DIR/i18n.sh"
#   init_lang "$CONFIG_FILE"
#   echo "$MSG_UPLOAD_COMPLETE"

# Initialize language from config
# Usage: init_lang <config_file>
init_lang() {
    local config_file="$1"
    local lang=""

    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # Default to English if not set or invalid
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # Load language messages
    load_messages "$lang"
}

# Load messages for specified language
load_messages() {
    local lang="$1"

    case "$lang" in
        zh|zh_CN|zh_TW)
            # Chinese messages
            MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
            MSG_CONFIG_FILE_EXISTS="配置文件已存在：%s"
            MSG_CONFIG_FILE_CREATED="已创建配置文件：%s"
            MSG_CONFIG_FIELDS_UPDATED="已更新配置字段"
            MSG_MISSING_FIELDS="以下字段尚未配置：%s"
            MSG_EDIT_CONFIG="请编辑 %s 补充配置"
            MSG_INIT_COMPLETE="初始化完成！"
            MSG_NEXT_STEPS="下一步："
            MSG_STEP_EDIT_CONFIG="  1. 编辑 %s 填写服务器信息"
            MSG_STEP_PLACE_KEY="  2. 将私钥文件放入 %s"
            MSG_STEP_TELL_CLAude="  3. 告诉 Claude：\"把代码同步到服务器\""

            MSG_KEYBIND_COMPLETE="私钥已绑定且权限正确：%s"
            MSG_KEY_PERMISSIONS_FIXED="已修正私钥权限：%s -> 600"
            MSG_NO_KEY_FOUND="未在 %s 下找到私钥文件"
            MSG_SUPPORTED_KEYS="支持的文件：%s"
            MSG_PLACE_KEY_IN_DIR="请将私钥文件放入 %s"
            MSG_KEY_BOUND="已绑定私钥：%s"
            MSG_CONFIG_UPDATED="配置已更新：%s"

            MSG_USING_PROJECT_PUBKEY="使用项目私钥对应的公钥：%s"
            MSG_USING_SYSTEM_PUBKEY="使用系统默认公钥：%s"
            MSG_NO_PUBKEY_FOUND="未找到公钥文件"
            MSG_GENERATE_KEYPAIR="请生成密钥对：ssh-keygen -t ed25519"
            MSG_NEED_SSH_COPY_ID="需要 ssh-copy-id 命令（OpenSSH 自带）"
            MSG_DEPLOYING_TO="部署公钥到 %s"
            MSG_PUBKEY_FILE="公钥文件：%s"
            MSG_ENTER_PASSWORD="根据提示输入服务器密码（密码不会显示）"
            MSG_PUBKEY_DEPLOYED="完成！公钥已部署到服务器"
            MSG_COPY_ID_NEXT_STEPS="下一步："
            MSG_STEP_COPY_PRIVATE_KEY="  1. 如果私钥还未放入 .claude/sftp-cc/，请复制进去"
            MSG_STEP_BIND_KEY="  2. 运行：bash %s/sftp-keybind.sh 绑定私钥"
            MSG_STEP_PUSH_FILES="  3. 运行：bash %s/sftp-push.sh 上传文件"
            MSG_OR_TELL_CLAUDE="或者对 Claude 说：'绑定私钥' 和 '把代码同步到服务器'"
            MSG_CONFIG_MISSING="配置文件不存在：%s"
            MSG_RUN_INIT_FIRST="请先运行 sftp-init.sh 初始化配置"
            MSG_CONFIG_INCOMPLETE="配置不完整，缺少：%s"

            MSG_CHECKING_KEYBIND="检查私钥绑定..."
            MSG_TARGET_SERVER="目标服务器：%s"
            MSG_CHECKING_CHANGES="检测文件变更..."
            MSG_FIRST_UPLOAD_FULL="首次上传，无历史推送记录，执行全量上传"
            MSG_SCANNING_FILES="全量扫描项目文件..."
            MSG_FOUND_FILES_FULL="找到 %s 个文件（全量）"
            MSG_FOUND_FILES_INCREMENTAL="检测到 %s 个变更文件（增量）"
            MSG_FOUND_FILES_DELETED="检测到 %s 个已删除文件"
            MSG_DELETE_NOT_ENABLED="未启用 --delete，跳过远程删除"
            MSG_NO_CHANGES="没有检测到文件变更，无需上传"
            MSG_UPLOADING_FILES="正在上传 %s 个文件到 %s ..."
            MSG_UPLOADING_DIR="正在上传目录 %s ..."
            MSG_SYNCING_INCREMENTAL="正在增量同步到 %s (上传 %s, 删除 %s) ..."
            MSG_ENSURE_REMOTE_DIR="确保远程目录存在..."
            MSG_UPLOAD_COMPLETE="上传完成！"
            MSG_DRY_RUN_MODE="[预览模式]"
            MSG_DRY_RUN_WILL_UPLOAD="[预览模式] 将上传 %s 个文件到 %s"
            MSG_DRY_RUN_BATCH_COMMANDS="[预览模式] 批处理命令:"
            MSG_DRY_RUN_BATCH_PREVIEW="[预览模式] 批处理命令 (前 20 行):"
            MSG_TOTAL_COMMANDS="  ... (共 %s 条命令)"
            MSG_FILE_NOT_FOUND="文件不存在，跳过：%s"
            MSG_UPLOAD_SUCCESS="已记录推送点：%s"
            MSG_PUSHING_DIR="推送目录：%s -> %s"

            MSG_UNKNOWN_OPTION="未知选项：%s"
            MSG_UNKNOWN_PARAMETER="未知参数：%s"
            MSG_REQUIRES_SFTP="需要 sftp 命令"
            MSG_RUN_SFTP_INIT_FIRST="请先运行 sftp-init.sh 初始化"
            MSG_EDIT_CONFIG_TO_COMPLETE="请编辑 %s 补充配置"
            MSG_UPLOAD_FAILED="上传失败 (exit code: %s)"
            MSG_NO_FILES_TO_UPLOAD="没有找到需要上传的文件"
            MSG_DIR_NOT_EXISTS="目录不存在：%s"
            MSG_COMMIT_INVALID="上次推送记录的 commit 已失效，将执行全量上传"
            MSG_SYNC_NO_CHANGES="没有需要同步的变更"
            MSG_DELETING_REMOTE="  x %s (远程删除)"
            ;;
        ja|ja_JP)
            # Japanese messages
            MSG_CONFIG_DIR_CREATED="設定ディレクトリを作成しました：%s"
            MSG_CONFIG_FILE_EXISTS="設定ファイルは既に存在します：%s"
            MSG_CONFIG_FILE_CREATED="設定ファイルを作成しました：%s"
            MSG_CONFIG_FIELDS_UPDATED="設定フィールドを更新しました"
            MSG_MISSING_FIELDS="未設定のフィールド：%s"
            MSG_EDIT_CONFIG="設定を編集してください：%s"
            MSG_INIT_COMPLETE="初期化が完了しました！"
            MSG_NEXT_STEPS="次のステップ："
            MSG_STEP_EDIT_CONFIG="  1. %s を編集してサーバー情報を入力"
            MSG_STEP_PLACE_KEY="  2. 秘密鍵ファイルを %s に配置"
            MSG_STEP_TELL_CLAude="  3. Claude に伝える：\"sync code to server\""

            MSG_KEYBIND_COMPLETE="秘密鍵がバインドされ、権限が修正されました：%s"
            MSG_KEY_PERMISSIONS_FIXED="秘密鍵の権限を修正：%s -> 600"
            MSG_NO_KEY_FOUND="%s に秘密鍵ファイルが見つかりません"
            MSG_SUPPORTED_KEYS="サポートされているファイル：%s"
            MSG_PLACE_KEY_IN_DIR="秘密鍵ファイルを %s に配置してください"
            MSG_KEY_BOUND="秘密鍵をバインドしました：%s"
            MSG_CONFIG_UPDATED="設定を更新しました：%s"

            MSG_USING_PROJECT_PUBKEY="プロジェクトの公開鍵を使用：%s"
            MSG_USING_SYSTEM_PUBKEY="システムのデフォルト公開鍵を使用：%s"
            MSG_NO_PUBKEY_FOUND="公開鍵ファイルが見つかりません"
            MSG_GENERATE_KEYPAIR="キーペアを生成してください：ssh-keygen -t ed25519"
            MSG_NEED_SSH_COPY_ID="ssh-copy-id コマンドが必要です（OpenSSH に付属）"
            MSG_DEPLOYING_TO="公開鍵を %s にデプロイ中"
            MSG_PUBKEY_FILE="公開鍵ファイル：%s"
            MSG_ENTER_PASSWORD="プロンプトが表示されたらサーバーのパスワードを入力（入力は非表示）"
            MSG_PUBKEY_DEPLOYED="完了！公開鍵をサーバーにデプロイしました"
            MSG_COPY_ID_NEXT_STEPS="次のステップ："
            MSG_STEP_COPY_PRIVATE_KEY="  1. 秘密鍵を .claude/sftp-cc/ にコピー（まだの場合）"
            MSG_STEP_BIND_KEY="  2. 実行：bash %s/sftp-keybind.sh 秘密鍵をバインド"
            MSG_STEP_PUSH_FILES="  3. 実行：bash %s/sftp-push.sh ファイルをアップロード"
            MSG_OR_TELL_CLAUDE="または Claude に伝える：'bind private key' と 'sync code to server'"
            MSG_CONFIG_MISSING="設定ファイルが見つかりません：%s"
            MSG_RUN_INIT_FIRST="最初に sftp-init.sh を実行して設定を初期化してください"
            MSG_CONFIG_INCOMPLETE="設定が不完全です。不足：%s"

            MSG_CHECKING_KEYBIND="秘密鍵のバインドを確認中..."
            MSG_TARGET_SERVER="ターゲットサーバー：%s"
            MSG_CHECKING_CHANGES="ファイルの変更を確認中..."
            MSG_FIRST_UPLOAD_FULL="初回アップロードです。履歴記録がないため、フルアップロードを実行します"
            MSG_SCANNING_FILES="プロジェクトファイルをスキャン中..."
            MSG_FOUND_FILES_FULL="%s 個のファイルが見つかりました（フル）"
            MSG_FOUND_FILES_INCREMENTAL="%s 個の変更ファイルを検出（増分）"
            MSG_FOUND_FILES_DELETED="%s 個の削除ファイルを検出"
            MSG_DELETE_NOT_ENABLED="削除モードが有効になっていません。リモート削除をスキップします"
            MSG_NO_CHANGES="変更が検出されませんでした。アップロードはありません"
            MSG_UPLOADING_FILES="%s 個のファイルを %s にアップロード中 ..."
            MSG_UPLOADING_DIR="ディレクトリ %s をアップロード中 ..."
            MSG_SYNCING_INCREMENTAL="%s に増分同期中（アップロード %s, 削除 %s） ..."
            MSG_ENSURE_REMOTE_DIR="リモートディレクトリの存在を確認中..."
            MSG_UPLOAD_COMPLETE="アップロード完了！"
            MSG_DRY_RUN_MODE="[ドライラン]"
            MSG_DRY_RUN_WILL_UPLOAD="[ドライラン] %s 個のファイルを %s にアップロードします"
            MSG_DRY_RUN_BATCH_COMMANDS="[ドライラン] バッチコマンド："
            MSG_DRY_RUN_BATCH_PREVIEW="[ドライラン] バッチコマンド（最初の 20 行）："
            MSG_TOTAL_COMMANDS="  ... (合計 %s コマンド)"
            MSG_FILE_NOT_FOUND="ファイルが見つかりません、スキップ：%s"
            MSG_UPLOAD_SUCCESS="プッシュポイントを記録：%s"
            MSG_PUSHING_DIR="ディレクトリをプッシュ：%s -> %s"

            MSG_UNKNOWN_OPTION="不明なオプション：%s"
            MSG_UNKNOWN_PARAMETER="不明なパラメータ：%s"
            MSG_REQUIRES_SFTP="sftp コマンドが必要です"
            MSG_RUN_SFTP_INIT_FIRST="最初に sftp-init.sh を実行してください"
            MSG_EDIT_CONFIG_TO_COMPLETE="設定を編集して完了してください：%s"
            MSG_UPLOAD_FAILED="アップロードに失敗しました (exit code: %s)"
            MSG_NO_FILES_TO_UPLOAD="アップロードするファイルが見つかりません"
            MSG_DIR_NOT_EXISTS="ディレクトリが存在しません：%s"
            MSG_COMMIT_INVALID="前回のプッシュコミットが無効です。フルアップロードを実行します"
            MSG_SYNC_NO_CHANGES="同期する変更はありません"
            MSG_DELETING_REMOTE="  x %s (リモート削除)"
            ;;
        *)
            # English messages (default)
            MSG_CONFIG_DIR_CREATED="Configuration directory created: %s"
            MSG_CONFIG_FILE_EXISTS="Config file already exists: %s"
            MSG_CONFIG_FILE_CREATED="Configuration file created: %s"
            MSG_CONFIG_FIELDS_UPDATED="Configuration fields updated"
            MSG_MISSING_FIELDS="Missing fields: %s"
            MSG_EDIT_CONFIG="Please edit %s to complete configuration"
            MSG_INIT_COMPLETE="Initialization complete!"
            MSG_NEXT_STEPS="Next steps:"
            MSG_STEP_EDIT_CONFIG="  1. Edit %s to fill in server information"
            MSG_STEP_PLACE_KEY="  2. Place private key file in %s"
            MSG_STEP_TELL_CLAUDE="  3. Tell Claude: \"sync code to server\""

            MSG_KEYBIND_COMPLETE="Private key bound and permissions corrected: %s"
            MSG_KEY_PERMISSIONS_FIXED="Fixed private key permissions: %s -> 600"
            MSG_NO_KEY_FOUND="No private key found in %s"
            MSG_SUPPORTED_KEYS="Supported files: %s"
            MSG_PLACE_KEY_IN_DIR="Please place private key file in %s"
            MSG_KEY_BOUND="Private key bound: %s"
            MSG_CONFIG_UPDATED="Configuration updated: %s"

            MSG_USING_PROJECT_PUBKEY="Using project public key: %s"
            MSG_USING_SYSTEM_PUBKEY="Using system default public key: %s"
            MSG_NO_PUBKEY_FOUND="No public key file found"
            MSG_GENERATE_KEYPAIR="Please generate a key pair: ssh-keygen -t ed25519"
            MSG_NEED_SSH_COPY_ID="Requires ssh-copy-id command (comes with OpenSSH)"
            MSG_DEPLOYING_TO="Deploying public key to %s"
            MSG_PUBKEY_FILE="Public key file: %s"
            MSG_ENTER_PASSWORD="Enter server password when prompted (hidden input)"
            MSG_PUBKEY_DEPLOYED="Complete! Public key deployed to server"
            MSG_COPY_ID_NEXT_STEPS="Next steps:"
            MSG_STEP_COPY_PRIVATE_KEY="  1. Copy private key to .claude/sftp-cc/ if not already placed"
            MSG_STEP_BIND_KEY="  2. Run: bash %s/sftp-keybind.sh to bind private key"
            MSG_STEP_PUSH_FILES="  3. Run: bash %s/sftp-push.sh to upload files"
            MSG_OR_TELL_CLAUDE="Or tell Claude: 'bind private key' and 'sync code to server'"
            MSG_CONFIG_MISSING="Configuration file not found: %s"
            MSG_RUN_INIT_FIRST="Please run sftp-init.sh first to initialize configuration"
            MSG_CONFIG_INCOMPLETE="Configuration incomplete, missing: %s"

            MSG_CHECKING_KEYBIND="Checking private key binding..."
            MSG_TARGET_SERVER="Target server: %s"
            MSG_CHECKING_CHANGES="Checking for file changes..."
            MSG_FIRST_UPLOAD_FULL="First upload, no history record. Performing full upload"
            MSG_SCANNING_FILES="Scanning project files..."
            MSG_FOUND_FILES_FULL="Found %s files (full)"
            MSG_FOUND_FILES_INCREMENTAL="Found %s files changed (incremental)"
            MSG_FOUND_FILES_DELETED="Found %s files deleted"
            MSG_DELETE_NOT_ENABLED="Delete mode not enabled, skipping remote deletion"
            MSG_NO_CHANGES="No changes detected, nothing to upload"
            MSG_UPLOADING_FILES="Uploading %s files to %s ..."
            MSG_UPLOADING_DIR="Uploading directory %s ..."
            MSG_SYNCING_INCREMENTAL="Syncing incrementally to %s (upload %s, delete %s) ..."
            MSG_ENSURE_REMOTE_DIR="Ensuring remote directory exists..."
            MSG_UPLOAD_COMPLETE="Upload complete!"
            MSG_DRY_RUN_MODE="[dry-run]"
            MSG_DRY_RUN_WILL_UPLOAD="[dry-run] Will upload %s files to %s"
            MSG_DRY_RUN_BATCH_COMMANDS="[dry-run] Batch commands:"
            MSG_DRY_RUN_BATCH_PREVIEW="[dry-run] Batch commands (first 20 lines):"
            MSG_TOTAL_COMMANDS="  ... (total %s commands)"
            MSG_FILE_NOT_FOUND="File not found, skipping: %s"
            MSG_UPLOAD_SUCCESS="Push point recorded: %s"
            MSG_PUSHING_DIR="Pushing directory: %s -> %s"

            MSG_UNKNOWN_OPTION="Unknown option: %s"
            MSG_UNKNOWN_PARAMETER="Unknown parameter: %s"
            MSG_REQUIRES_SFTP="Requires sftp command"
            MSG_RUN_SFTP_INIT_FIRST="Please run sftp-init.sh first"
            MSG_EDIT_CONFIG_TO_COMPLETE="Please edit %s to complete configuration"
            MSG_UPLOAD_FAILED="Upload failed (exit code: %s)"
            MSG_NO_FILES_TO_UPLOAD="No files to upload found"
            MSG_DIR_NOT_EXISTS="Directory does not exist: %s"
            MSG_COMMIT_INVALID="Last push commit is invalid, will perform full upload"
            MSG_SYNC_NO_CHANGES="No changes to sync"
            MSG_DELETING_REMOTE="  x %s (remote delete)"
            ;;
    esac
}

# Helper function to print formatted message
# Usage: printf_msg "$MSG_FORMAT" "arg1" "arg2" ...
printf_msg() {
    local format="$1"
    shift
    printf "%s\n" "$(printf "$format" "$@")"
}
