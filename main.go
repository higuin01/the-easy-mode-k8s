package main

import (
        "fmt"
        "os"

        "github.com/higor-easy-mode/pkg/cluster"
        "github.com/higor-easy-mode/pkg/config"
        "github.com/higor-easy-mode/pkg/ui"
)

func main() {
        // Initialize configuration
        cfg := config.NewConfig()
        if err := cfg.ValidateScriptsDir(); err != nil {
                fmt.Printf("Erro: diretório de scripts não encontrado: %v\n", err)
                os.Exit(1)
        }

        // Initialize cluster manager
        manager := cluster.NewManager(cfg)

        // Initialize menu
        menu := ui.NewMenu(manager)

        // Main application loop
        for {
                // Show header with cluster status
                menu.PrintHeader()

                // Get cluster status for menu options
                clusterActive, err := manager.GetClusterStatus()
                if err != nil {
                        fmt.Printf("Erro ao verificar status do cluster: %v\n", err)
                        os.Exit(1)
                }

                // Show menu options
                menu.PrintMenu(clusterActive)

                // Get and process user input
                option := menu.GetUserInput()
                menu.ExecuteOption(option, clusterActive)
        }
}

