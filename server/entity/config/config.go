// Package config 定义应用配置结构体、默认值与校验规则。
//
// 配置的读取（YAML 文件查找与反序列化）见 server/config 包。
package config

import (
	"errors"
	"fmt"
	"os"

	cacheConfig "github.com/hecc-blot/cache/config"
	logConfig "github.com/hecc-blot/core/config/log"
	dbConfig "github.com/hecc-blot/db/config"
	serverConfig "github.com/hecc-blot/framework/config/http"
	envEnum "github.com/hecc-blot/framework/enum/env"
	mqConfig "github.com/hecc-blot/mq/config"
	traceConfig "github.com/hecc-blot/trace/config"
)

// Config 是应用配置的根节点。
//
// 基础设施部分的配置结构体直接复用 hecc-blot 各模块的 config 包，
// 避免同一份 YAML 在框架与本项目之间出现两份定义。
type Config struct {
	App     AppConfig             `mapstructure:"app"`
	Server  serverConfig.Config   `mapstructure:"server"`
	Log     logConfig.LocalConfig `mapstructure:"log"`
	Db      dbConfig.Config       `mapstructure:"db"`
	Cache   cacheConfig.Config    `mapstructure:"cache"`
	Trace   traceConfig.Config    `mapstructure:"trace"`
	Mq      mqConfig.Config       `mapstructure:"mq"`
	Session SessionConfig         `mapstructure:"session"`
	Upload  UploadConfig          `mapstructure:"upload"`
}

// AppConfig 应用自身信息。
type AppConfig struct {
	Name       string `mapstructure:"name"`
	Version    string `mapstructure:"version"`
	InstanceID string `mapstructure:"instance_id"` // 多实例部署时用于 SSE 消费组，默认 hostname-port
}

// SessionConfig 服务端会话配置（阶段 3 使用）。
type SessionConfig struct {
	IdleTimeout     int `mapstructure:"idle_timeout"`     // 滑动空闲过期，秒
	AbsoluteTimeout int `mapstructure:"absolute_timeout"` // 绝对过期，秒
	MaxPerUser      int `mapstructure:"max_per_user"`     // 单用户最大会话数，0 表示不限制
	TokenBytes      int `mapstructure:"token_bytes"`      // 随机 token 字节数
}

// UploadConfig 文件上传配置（阶段 5 使用）。
type UploadConfig struct {
	Driver            string   `mapstructure:"driver"`
	Dir               string   `mapstructure:"dir"`
	MaxSize           int64    `mapstructure:"max_size"`
	AllowedExtensions []string `mapstructure:"allowed_extensions"`
}

// ApplyDefaults 补全未配置项的默认值。
//
// 在 viper 反序列化之后、Validate 之前调用。
func (c *Config) ApplyDefaults() {
	if c.App.Name == "" {
		c.App.Name = "hecc-admin"
	}
	if c.App.Version == "" {
		c.App.Version = "0.1.0"
	}
	if c.Server.Env == "" {
		c.Server.Env = envEnum.DevMode
	}
	if c.Server.Port == "" {
		c.Server.Port = "8080"
	}
	if c.Server.BodySizeLimit <= 0 {
		c.Server.BodySizeLimit = 10 << 20
	}
	if c.App.InstanceID == "" {
		host, err := os.Hostname()
		if err != nil || host == "" {
			host = "instance"
		}
		c.App.InstanceID = fmt.Sprintf("%s-%s", host, c.Server.Port)
	}

	if c.Log.RootDir == "" {
		c.Log.RootDir = "logs"
	}
	if c.Log.MaxSize <= 0 {
		c.Log.MaxSize = 100
	}
	if c.Log.MaxBackups <= 0 {
		c.Log.MaxBackups = 7
	}
	if c.Log.MaxAge <= 0 {
		c.Log.MaxAge = 30
	}

	if c.Db.Default == "" {
		c.Db.Default = "postgres"
	}

	if c.Trace.ServiceName == "" {
		c.Trace.ServiceName = c.App.Name
	}
	if c.Trace.Sampler.Type == "" {
		c.Trace.Sampler.Type = "never"
	}
	if c.Trace.Endpoint == "" {
		c.Trace.Endpoint = "127.0.0.1:4318"
	}

	// MQ 默认值由 mq.Config.Normalize 在构造工厂时补齐，这里只补消费并发。
	if c.Mq.Consumer.Concurrency <= 0 {
		c.Mq.Consumer.Concurrency = 1
	}

	if c.Session.IdleTimeout <= 0 {
		c.Session.IdleTimeout = 2 * 60 * 60
	}
	if c.Session.AbsoluteTimeout <= 0 {
		c.Session.AbsoluteTimeout = 12 * 60 * 60
	}
	if c.Session.TokenBytes <= 0 {
		c.Session.TokenBytes = 32
	}

	if c.Upload.Driver == "" {
		c.Upload.Driver = "local"
	}
	if c.Upload.Dir == "" {
		c.Upload.Dir = "storage/uploads"
	}
	if c.Upload.MaxSize <= 0 {
		c.Upload.MaxSize = 10 << 20
	}

}

// Validate 校验启动所必需的配置项。
func (c *Config) Validate() error {
	switch c.Server.Env {
	case envEnum.DevMode, envEnum.TestMode, envEnum.ProductMode:
	default:
		return fmt.Errorf("server.env 非法：%q（可选 dev / test / product）", c.Server.Env)
	}
	if c.Server.Port == "" {
		return errors.New("server.port 不能为空")
	}
	if c.Db.Postgres == nil {
		return errors.New("db.postgres 未配置")
	}
	if c.Db.Postgres.Ip == "" {
		return errors.New("db.postgres.ip 不能为空")
	}
	if c.Db.Postgres.Port <= 0 {
		return errors.New("db.postgres.port 必须大于 0")
	}
	if c.Db.Postgres.DbName == "" {
		return errors.New("db.postgres.db_name 不能为空")
	}
	if c.Cache.Redis.Addr == "" {
		return errors.New("cache.redis.addr 不能为空（会话依赖 Redis）")
	}
	if c.Session.AbsoluteTimeout <= c.Session.IdleTimeout {
		return errors.New("session.absolute_timeout 必须大于 session.idle_timeout")
	}
	return nil
}
