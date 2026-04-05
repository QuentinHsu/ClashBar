English | [简体中文](README.zh-CN.md)

<div align="center">

<img src="Sources/CatBar/Resources/Assets.xcassets/BrandLogo.imageset/logo.png" width="300" alt="CatBar Logo" style="border-radius: 68px;" />

# CatBar

Menu bar control panel for `mihomo` on macOS, bringing together proxies, rules, connections, logs, and core management in one place.

<p>
  <img alt="Platform" src="https://img.shields.io/badge/macOS-13%2B-111111?style=flat&logo=apple" />
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.2-F05138?style=flat&logo=swift" />
  <img alt="Build" src="https://img.shields.io/badge/Build-SwiftPM-0A84FF?style=flat" />
  <img alt="i18n" src="https://img.shields.io/badge/i18n-zh--Hans%20%7C%20en-34C759?style=flat" />
  <a href="https://github.com/QuentinHsu/cat-bar/releases" target="_blank" rel="noopener noreferrer">
    <img alt="Version" src="https://img.shields.io/github/v/release/QuentinHsu/cat-bar?style=flat&logo=github" />
  </a>
  <a href="https://github.com/QuentinHsu/cat-bar/releases">
    <img src="https://img.shields.io/github/downloads/QuentinHsu/cat-bar/total?style=flat-square&logo=dropbox&logoColor=white&color=green" alt="Downloads">
  </a>
</p>

<p>
  <img src="docs/static-resources/app-screenshot-dark.webp" alt="CatBar App Screenshot" width="300" style="border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
</p>

</div>

---

## Overview

This repository is forked from [Sitoi/ClashBar](https://github.com/Sitoi/ClashBar) and is actively extended and maintained with custom improvements.

## Release Notes

This repository currently publishes the `no-core` edition only. It does not bundle any Clash / mihomo core binary and ships the app panel plus related management features only.

To enable core functionality, place a compatible `mihomo` executable at:

`~/Library/Application Support/catbar/core/`

CatBar will load the local core from that directory.

## Contributors

Thanks to everyone who has contributed to the project:

[![Contributors](https://contrib.rocks/image?repo=QuentinHsu/cat-bar)](https://github.com/QuentinHsu/cat-bar/graphs/contributors)

## Acknowledgements

- Special thanks to [Sitoi](https://github.com/Sitoi), the original author of [Sitoi/ClashBar](https://github.com/Sitoi/ClashBar), which provided the foundation for this project.
- Special thanks as well to [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the stable and reliable core capabilities.

## Star History

[![Star History Chart](https://starchart.cc/QuentinHsu/cat-bar.svg?variant=adaptive)](https://starchart.cc/QuentinHsu/cat-bar)

## License

[GPL-3.0](LICENSE)
