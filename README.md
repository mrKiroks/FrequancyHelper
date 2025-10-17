# 📡 Frequency Helper  
Универсальный помощник для деп-чата SA-MP

[![SA-MP](https://img.shields.io/badge/SA--MP-0.3.7+-orange?style=flat-square)](https://sa-mp.com)
[![MoonLoader](https://img.shields.io/badge/MoonLoader-027-blue?style=flat-square)](https://moonloader.ru)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

## Что это
Frequency Helper упрощает жизнь игрокам гос. структур:  
хранит список организаций, шаблоны сообщений и в один клик отправляет нужную фразу в `/d` .  
Скрипт работает **на всех серверах**.

## Две версии
| Версия | Что умеет | Серверы |
|--------|-----------|---------|
| **UX** (Universal eXchange) | Шаблоны `/d`, собеседование, чат-лог | **Любые сервера** |
| **RX** (Radio eXchange) | То же + **частоты** `/d`, фильтр по организации | Подходит только для сервера Saint-Rose* |


## Базовые возможности (обе версии)
- Горячие клавиши и GUI – ничего лишнего в чате  
- Редактор организаций и шаблонов в реальном времени  
- Авто-сохранение настроек в UTF-8 (`frequency_helper.ini`)  
- Окно просмотра деп-чата

## Установка (общая)
1. Установи зависимости:  
   [MoonLoader](https://www.blast.hk/threads/13305/) + [samp.lua](https://www.blast.hk/threads/14624/) + [mimgui](https://www.blast.hk/threads/66959/)  
   *(для UX ещё [fAwesome6](https://www.blast.hk/threads/111224/))*

2. Скопируй `frequency_helper_ux.lua` **или** `frequency_helper_rx.lua` в папку `moonloader`.

3. Запусти игру. В чате появится подсказка `/freq`.

## Лицензия
MIT © 2025 mrKiroks & mr_kiroks
