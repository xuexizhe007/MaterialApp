物资管理系统 V2.0 (Flutter App版)

【本次改进】
1. 物资信息不再要求填写“物资编码”。
   - 新增/编辑物资只需要名称和备注。
   - 旧数据里的 code 字段会继续保留，历史记录、扫码兼容不受影响。
2. 入库、出库支持一次处理多个物品。
   - 入库页和出库页均可点击“新增一项”添加物资行。
   - 同一次提交会生成同一个单号 batchId，多条物资记录共用该单号。
   - 导出单据时，同一次出/入库的多个物资会合并显示在一张 PDF 单据中。
3. 新增“统计”页。
   - 用户可自定义开始、结束日期。
   - 入库、出库分别统计，只显示有记录的物资。
   - 按统计数量降序排列。
4. 补充 Android 平台工程目录，便于在 Android Studio 中打开 Flutter 项目并构建 APK。

【如何运行】
1. 确保电脑已安装 Flutter SDK 和 Android Studio。
2. 解压本文件夹。
3. 使用 Android Studio 打开本项目根目录。
4. 运行 `flutter pub get` 下载依赖。
5. 连接手机或启动模拟器，运行 `flutter run`，或执行 `flutter build apk --release --no-tree-shake-icons` 构建 APK。

【功能说明】
- 登录：输入任意用户名登录，App 会记住当前操作员。
- 目录/入库：维护物资目录，支持多物资批量入库。
- 出库：支持多物资批量出库，并自动校验库存。
- 统计：自定义时间范围统计入库和出库数量。
- 数据：所有数据保存在手机本地 SharedPreferences 中。
- 备份：可导出/导入 JSON 备份文件。
- 单据：可在“设置/库存 -> 出入库记录 / 单据导出”中导出 PDF。

【技术栈】
- Flutter (Dart)
- Provider
- SharedPreferences
- Pdf / Printing
- Mobile Scanner
- File Picker / Share Plus
