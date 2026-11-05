// 在 OpenCode V2 Web 页面的浏览器开发者工具 Console 中执行。
// 这些偏好属于当前浏览器站点，不由服务端 opencode.jsonc 管理。
(() => {
  function readObject(key) {
    const value = JSON.parse(localStorage.getItem(key) ?? "{}");
    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      throw new Error(`无法合并浏览器设置：${key} 不是对象`);
    }
    return value;
  }

  // OpenCode V2.2.5 的 Web 存储键；升级后应先核对客户端实现。
  const settings = readObject("settings.v3");
  const language = readObject("opencode.global.dat:language");
  settings.general = { ...settings.general, showCustomAgents: true };
  settings.appearance = {
    ...settings.appearance,
    tabLayout: "inbox",
    sidebarOpen: true,
  };
  language.locale = "en";

  localStorage.setItem("settings.v3", JSON.stringify(settings));
  localStorage.setItem("opencode.global.dat:language", JSON.stringify(language));
  location.reload();
})();
