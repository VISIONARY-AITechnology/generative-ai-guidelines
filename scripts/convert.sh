#!/bin/bash
# ============================================================
# convert.sh
# 元のMarkdownファイルからmdbookのsrc/構成を自動生成する
# Usage: ./scripts/convert.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$ROOT_DIR/src"

# 元ファイル
MAIN="$ROOT_DIR/生成AI導入ガイドライン.md"
CHECKLIST="$ROOT_DIR/生成AI利用チェックリスト.md"
EXCEPTION="$ROOT_DIR/例外申請テンプレ.md"
FLOWCHART="$ROOT_DIR/判断フローチャート.md"
TRACEABILITY="$ROOT_DIR/要件トレーサビリティ表.md"

# -----------------------------------------------------------
# 前準備: src/ をクリーンアップ（SUMMARY.md含めて再生成）
# -----------------------------------------------------------
echo "🔄 src/ をクリーンアップ..."
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"

# -----------------------------------------------------------
# 1. メインガイドラインのヘッダー部分 → introduction.md
# -----------------------------------------------------------
echo "📖 introduction.md を生成..."

# 「## 第1章」の直前までをヘッダーとして抽出
CHAPTER1_LINE=$(grep -n '^## 第1章' "$MAIN" | head -1 | cut -d: -f1)

# ヘッダー部分から introduction を生成
head -n $((CHAPTER1_LINE - 1)) "$MAIN" | sed '/^## 目次$/,/^---$/d' > "$SRC_DIR/introduction.md"

# 末尾の「関連ドキュメント」「改定履歴」「根拠資料」セクションを抽出して introduction に追記
RELATED_LINE=$(grep -n '^## 関連ドキュメント' "$MAIN" | head -1 | cut -d: -f1)
if [ -n "$RELATED_LINE" ]; then
  tail -n +"$RELATED_LINE" "$MAIN" >> "$SRC_DIR/introduction.md"
fi

# introduction 内の関連ドキュメントリンクをmdbook用パスに変換
sed -i '' \
  -e 's|\./生成AI利用チェックリスト\.md|./checklist.md|g' \
  -e 's|\./例外申請テンプレ\.md|./exception.md|g' \
  -e 's|\./判断フローチャート\.md|./flowchart.md|g' \
  -e 's|\./要件トレーサビリティ表\.md|./traceability.md|g' \
  "$SRC_DIR/introduction.md"

# -----------------------------------------------------------
# 2. メインガイドラインを章ごとに分割 → chapter_XX.md
# -----------------------------------------------------------
echo "📚 メインガイドラインを章分割..."

# 「## 第X章」の行番号を取得
CHAPTER_LINES=()
while IFS= read -r line; do
  CHAPTER_LINES+=("$line")
done < <(grep -n '^## 第[0-9]*章' "$MAIN" | cut -d: -f1)

# 「## 関連ドキュメント」の行番号（章の終端）
END_LINE=$(grep -n '^## 関連ドキュメント' "$MAIN" | head -1 | cut -d: -f1)
# 関連ドキュメントセクションがなければファイル末尾
if [ -z "$END_LINE" ]; then
  END_LINE=$(wc -l < "$MAIN")
fi

TOTAL_CHAPTERS=${#CHAPTER_LINES[@]}

for i in $(seq 0 $((TOTAL_CHAPTERS - 1))); do
  START=${CHAPTER_LINES[$i]}

  # 次の章の開始行 or 関連ドキュメントセクション
  if [ $i -lt $((TOTAL_CHAPTERS - 1)) ]; then
    NEXT=${CHAPTER_LINES[$((i + 1))]}
  else
    NEXT=$END_LINE
  fi

  # 章番号（ゼロ埋め2桁）
  CHAPTER_NUM=$(printf "%02d" $((i + 1)))
  OUTFILE="$SRC_DIR/chapter_${CHAPTER_NUM}.md"

  # 抽出して ## → # に変換
  sed -n "${START},$((NEXT - 1))p" "$MAIN" \
    | sed 's/^## /# /' \
    > "$OUTFILE"

  # 末尾の空行と区切り線を除去
  while tail -1 "$OUTFILE" | grep -qE '^[[:space:]]*$|^---$'; do
    sed -i '' '$ d' "$OUTFILE"
  done

  # 章タイトルを取得して表示
  TITLE=$(head -1 "$OUTFILE" | sed 's/^# //')
  echo "  ✅ chapter_${CHAPTER_NUM}.md - ${TITLE}"
done

# -----------------------------------------------------------
# 3. 付属文書をコピー
# -----------------------------------------------------------
echo "📎 付属文書をコピー..."

cp "$CHECKLIST"     "$SRC_DIR/checklist.md"
cp "$EXCEPTION"     "$SRC_DIR/exception.md"
cp "$FLOWCHART"     "$SRC_DIR/flowchart.md"
cp "$TRACEABILITY"  "$SRC_DIR/traceability.md"

# 付属文書内の相互リンクをmdbook用パスに変換
for f in "$SRC_DIR/checklist.md" "$SRC_DIR/exception.md" "$SRC_DIR/flowchart.md" "$SRC_DIR/traceability.md"; do
  sed -i '' \
    -e 's|\./生成AI導入ガイドライン\.md|./introduction.md|g' \
    -e 's|\./生成AI利用チェックリスト\.md|./checklist.md|g' \
    -e 's|\./例外申請テンプレ\.md|./exception.md|g' \
    -e 's|\./判断フローチャート\.md|./flowchart.md|g' \
    -e 's|\./要件トレーサビリティ表\.md|./traceability.md|g' \
    "$f"
done

echo "  ✅ checklist.md, exception.md, flowchart.md, traceability.md"

# -----------------------------------------------------------
# 4. SUMMARY.md を生成
# -----------------------------------------------------------
echo "📝 SUMMARY.md を生成..."

{
  echo "# Summary"
  echo ""
  echo "[はじめに](./introduction.md)"
  echo ""
  echo "---"
  echo ""
  echo "# 生成AI導入ガイドライン"
  echo ""

  # 各章のタイトルをファイルから読み取って目次生成
  for i in $(seq 1 "$TOTAL_CHAPTERS"); do
    CHAPTER_NUM=$(printf "%02d" "$i")
    TITLE=$(head -1 "$SRC_DIR/chapter_${CHAPTER_NUM}.md" | sed 's/^# //')
    echo "- [${TITLE}](./chapter_${CHAPTER_NUM}.md)"
  done

  echo ""
  echo "---"
  echo ""
  echo "# 付属文書"
  echo ""
  echo "- [生成AI利用チェックリスト](./checklist.md)"
  echo "- [判断フローチャート](./flowchart.md)"
  echo "- [例外申請書テンプレート](./exception.md)"
  echo "- [要件トレーサビリティ表](./traceability.md)"
} > "$SRC_DIR/SUMMARY.md"

echo "  ✅ SUMMARY.md"

# -----------------------------------------------------------
# 完了
# -----------------------------------------------------------
echo ""
echo "🎉 変換完了！"
echo "   生成ファイル数: $(find "$SRC_DIR" -name '*.md' | wc -l | tr -d ' ')"
echo ""
echo "   ビルド:    mdbook build"
echo "   プレビュー: mdbook serve --open"
