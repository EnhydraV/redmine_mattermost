package main

import (
	"fmt"
	"strings"
)

type configuration struct {
	AllowedUsernames string
	MatchByEmail     bool
}

// isAllowed indique si le compte appelant fait partie des comptes Redmine autorisés.
func (c *configuration) isAllowed(username string) bool {
	for _, name := range strings.Split(c.AllowedUsernames, ",") {
		name = strings.TrimPrefix(strings.TrimSpace(name), "@")
		if name != "" && strings.EqualFold(name, username) {
			return true
		}
	}
	return false
}

func (p *Plugin) getConfiguration() *configuration {
	p.configurationLock.RLock()
	defer p.configurationLock.RUnlock()

	if p.configuration == nil {
		return &configuration{}
	}
	return p.configuration
}

func (p *Plugin) setConfiguration(cfg *configuration) {
	p.configurationLock.Lock()
	defer p.configurationLock.Unlock()

	p.configuration = cfg
}

// OnConfigurationChange recharge les réglages, valeurs par défaut du manifeste comprises.
func (p *Plugin) OnConfigurationChange() error {
	cfg := new(configuration)
	if err := p.API.LoadPluginConfiguration(cfg); err != nil {
		return fmt.Errorf("failed to load plugin configuration: %w", err)
	}
	p.setConfiguration(cfg)
	return nil
}
