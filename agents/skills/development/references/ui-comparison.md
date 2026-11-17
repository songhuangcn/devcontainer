# UI 对比附件

## 生成与检查

- 通过真实浏览器保存截图，用 Pillow、ImageMagick 等确定性工具拼接，不使用生成式图像替代实际页面。
- PC 图按页面/状态纵向排列，每行左 Before、右 After；保留清晰文字、对齐的截图区域和版本标识。需要在 IM 转发时提供单张 PNG 原图。
- 截图和拼接脚本放仓库外临时目录或项目忽略的测试产物目录。拼接后实际打开检查，确认页面没有截断、标签没有颠倒，也没有混入移动端截图或敏感信息。

## GitHub 原生图片附件

以下接口可上传到仓库关联的 `user-attachments`，无需把图片提交到 Git。它是未公开保证稳定性的接口；失败时不要宣称已上传，也不要未经允许改用公开图床。

先用 `gh auth status` 确认身份，获取目标仓库 ID，再上传 PNG。不要打印 token、开启 shell trace，或把凭证写进脚本/日志：

```bash
repo="owner/repo"
image="/path/to/ui-comparison.png"
repo_id="$(gh api "repos/$repo" --jq .id)"

curl -4 --http1.1 --fail-with-body --silent --show-error \
  --connect-timeout 15 --max-time 90 \
  --config - \
  --header 'Accept: application/json' \
  --header 'Content-Type: image/png' \
  --data-binary "@$image" \
  "https://uploads.github.com/user-attachments/assets?name=ui-comparison.png&content_type=image%2Fpng&repository_id=$repo_id" \
  <<< "header = \"Authorization: Bearer $(gh auth token)\""
```

成功响应含 `url`，形如 `https://github.com/user-attachments/assets/<id>`。将实际返回的 URL 写进 PR 正文或评论：

```markdown
## UI 前后对比（PC）

左：调整前（base 提交）；右：调整后（当前提交）。
改动：……；已验证：……；未验证或阻塞：……。

[下载 / 打开 PNG 原图](实际附件 URL)
![PC 前后对比长图](实际附件 URL)
```

用 `gh pr comment <number> --repo "$repo" --body-file <临时 Markdown 文件>` 发布评论，或局部更新 PR 正文，保留已有内容。发布后回读确认 URL 和图片标记已写入；不重复创建相同评论。
