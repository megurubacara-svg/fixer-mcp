package main

var validSessionStatuses = map[string]struct{}{
	"pending":     {},
	"in_progress": {},
	"review":      {},
	"completed":   {},
}

const (
	forcedMcpServerName         = "fixer_mcp"
	philologistsProjectMarker   = "philologists"
	researchQueryMcpName        = "research_query_mcp"
	telegramNotifyMcpName       = "telegram_notify"
	defaultTelegramAPIBaseURL   = "https://api.telegram.org"
	explicitLaunchDefaultWait   = 7200
	explicitLaunchMaxWait       = 21600
	explicitLaunchDefaultPoll   = 5
	explicitLaunchMaxPoll       = 60
	defaultDeclaredWriteScope   = `["."]`
	defaultWriteScopePath       = "."
	defaultCliBackend           = "codex"
	defaultCliModel             = "gpt-5.6-luna"
	defaultCliReasoning         = "xhigh"
	defaultDroidCliModel        = "kimi-k2.6"
	defaultDroidCliReasoning    = "high"
	defaultAntigravityReasoning = "default"
	defaultKimiCodeCliModel     = "kimi-k2.7-code"
	defaultKimiCodeReasoning    = "default"
	defaultJunieCliReasoning    = "default"
	reworkRepairThreshold       = 2
	workerStatusRunning         = "running"
	workerStatusStopped         = "stopped"
	workerStatusExited          = "exited"
)

var supportedCliBackends = map[string]struct{}{
	"antigravity": {},
	"codex":       {},
	"droid":       {},
	"junie":       {},
	"kimi-code":   {},
}

var cliBackendAliases = map[string]string{
	"agy": "antigravity",
}

var droidLegacyModelAliases = map[string]string{
	"kimi":                      defaultDroidCliModel,
	"kimi k2.6":                 defaultDroidCliModel,
	"kimi-k2.6":                 defaultDroidCliModel,
	"kimi k2.6 [kimi]":          defaultDroidCliModel,
	"custom:kimi-k2.6-[kimi]-0": defaultDroidCliModel,
	"kimi-k2.7-code":            "kimi-k2.7-code",
	"kimi-k2.7":                 "kimi-k2.7-code",
	"kimi k2.7 code":            "kimi-k2.7-code",
	"glm-5.1":                   "glm-5.1",
	"z.ai glm-5.1":              "glm-5.1",
	"z.ai glm 5.1":              "glm-5.1",
	"custom:glm-5.1-[z.ai]-0":   "glm-5.1",
}

var supportedDroidCliModels = map[string]struct{}{
	defaultDroidCliModel: {},
	"kimi-k2.7-code":     {},
	"glm-5.1":            {},
}
