# dotfiles

Configs personalizadas para Arch Linux e Ubuntu.

## Quick Install

```bash
git clone https://github.com/JhimmyLiborio/dotfiles.git
cd dotfiles
./setup.sh
```

## What's Included

| App | Config Path | Description |
|-----|-------------|-------------|
| Bash | `~/.bashrc`, `~/.bash_profile` | Prompt colorido, aliases multi-distro, funcoes utilitarias |
| Neovim | `~/.config/nvim/init.lua` | Config basica com clipboard Wayland |
| Tmux | `~/.config/tmux/tmux.conf` | Prefix `C-s`, vim bindings, status bar solarized, popup bindings |
| Kanata | `~/.config/kanata/config.kbd` | Home row mods (GACS), ESC/Caps swap, layer toggle via RSFT |
| tmux-sessionizer | `~/.config/tmux-sessionizer/` | Navegacao entre projetos via popup |

## What the Script Does

1. **Detecta distro** (Arch, Ubuntu, Fedora) e instala pacotes via gerenciador correto
2. **Instala ferramentas**: neovim, tmux, fzf, bat, ripgrep, fd, zoxide
3. **Instala kanata** (binario em `~/.bin/kanata` ou via pacman)
4. **Cria bare repo** em `~/.dotfiles` para gerenciar configs com git
5. **Faz checkout** dos configs no `$HOME` (com backup automatico)
6. **Configura kanata** como systemd user service (com udev rules e grupos)

## Bare Repo Workflow

O repo usa **bare git repo** para versionar configs do `$HOME`:

```bash
# Ver status das configs
dotfiles status

# Adicionar mudanca
dotfiles add ~/.config/nvim/init.lua

# Commit
dotfiles commit -m "atualizei nvim"

# Push
dotfiles push
```

O alias `dotfiles` e adicionado ao `.bashrc` pelo script.

## Dependencies

### Manual install (se nao usar setup.sh)

**Arch Linux:**
```bash
sudo pacman -S git curl neovim tmux fzf bat ripgrep fd kanata
```

**Ubuntu/Debian:**
```bash
sudo apt install git curl neovim tmux fzf bat ripgrep fd-find
# kanata: https://github.com/jtroo/kanata/releases
```

**Opcional:**
- [zoxide](https://github.com/ajeetdsouza/zoxide) - `cd` inteligente
- [tmux-sessionizer](https://github.com/joshmedeski/tmux-sessionizer) - `cargo install tmux-sessionizer`

## Kanata Setup (Home Row Mods)

O kanata ativa **home row mods** na camada `hrm`:

| Tecla | Modificador |
|-------|-------------|
| A | LGUI (Super) |
| S | LALT (Alt) |
| D | LCTRL |
| F | LSHIFT |
| J | RSHIFT |
| K | RCTRL |
| L | RALT |
| ; | RGUI (Super) |

**Toggle:** Pressione e segure `RSFT` para alternar entre camada `plain` (normal) e `hrm` (home row mods).

**Apos instalar:** Faca logout/login para ativar os grupos `uinput` e `input`.

## Adicionando Novos Configs

1. Copie o arquivo para o repo:
   ```bash
   cp ~/.config/novo-app/config ~/.config/novo-app/config
   ```
2. Adicione ao bare repo:
   ```bash
   dotfiles add ~/.config/novo-app/config
   dotfiles commit -m "add novo-app config"
   ```
3. Push:
   ```bash
   dotfiles push
   ```

## Backup

O setup.sh cria backups automaticos em `~/.config-backup-YYYYMMDD-HHMMSS/` antes de sobrescrever configs existentes.

## License

MIT
