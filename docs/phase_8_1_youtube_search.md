# Phase 8.1 — YouTube Public Search

## Overview
Provides public YouTube video metadata search capabilities without relying on API keys, cloud servers, or third-party paid proxies.

## Architecture
- **Scraper Layer** (`YouTubeScraper`): Fetches public search results with custom User-Agent, timeout handling, and debounce protection.
- **Parser Layer** (`YouTubeParser`): Extracts embedded `ytInitialData` renderer trees & video metadata.
- **Normalizer Layer** (`YouTubeNormalizer`): Sanitizes video titles (removing noise like `[Official Video]`, `HD`, etc.) and formats durations & thumbnails.
- **Search Cache**: Cached locally in SQLite (`youtube_search_cache`) with a 1-hour TTL.
