# Payment Integration Generator

Gem для генерации класса интеграции на основе спецификации OpenAPI >=3.0
Ruby (>3.0)

## Принцип работы

В коде gem'а имеется набор **генераторов** (`lib/payment_integration_generator/generators/`), каждый из которых отвечает за генерацию конкретного итогового файла (`client_service.rb`, `INTEGRATION.md`, `fixtures.json`) 

Генерация итоговых файлов происходит при помощи **erb шаблонов** (`lib/templates`):
 - `lib/templates/class.erb` - отвечает за формирование самого файла класса-интеграции
 - `lib/templates/integration_md.erb` - отвечает за формирование файла документации

*файл фикстур (`fixtures.json`) формируется исключительно в рамках генератора `lib/payment_integration_generator/generators/fixtures_generator.rb` без использования шаблонов*

Поиск необходимых ендпоинтов для методов класса-интеграции происходит в соответсвующих **серчерах** (`lib/payment_integration_generator/searchers/`). Прицип поиска построен следующим образом:
 - Серчер проходит по каждому ендпоинту
 - По текстовому поиску на основе ключевых слов определяет релевантность ендпоинта, назначая ему **рейтинг релевантности** по количеству вхождения ключевых слов в различные части спецификации, относящейся к данному ендпоинту
 - Затем выбирается ендпоинт с самым высоким рейтингом, который передается на согласование пользователю
 - Пользователь выбирает одну из трех опций:
   - `YES` - выполнить генерацию с данным ендпоинтом
   - `ToDO` - пропустить генерацию метода и заполнить её в дальнейшем вручную
   - указать определенный ендпоинт в формате `method /endpoint` (пример `post /payment`)
 - После выбора опции утилита переходит к генерации следующего метода или завершает свою работу

## Расширение функционала

Таким образом, если потребуется расширить функционал gem'а - например, добавить генерацию новый метод в итоговый класс-клиент, то необходимо:
 - Добавить имя метода в `PaymentIntegrationGenerator::IntegrationGenerator::PROVIDER_PUBLIC_METHODS` или `PaymentIntegrationGenerator::IntegrationGenerator::PROVIDER_PRIVATE_METHODS`
 - Создать шаблон в `lib/templates/provider_methods` с соответсвующим методу именем
 - При необходимости создать серчер в `lib/payment_integration_generator/searchers` и указать в нём правила поиска ендпоинта в спецификации OpenAPI
 - Так же добавить новый сёрчер в `PaymentIntegrationGenerator::IntegrationGenerator::SEARCHERS` и `PaymentIntegrationGenerator::IntegrationGenerator::SEARCHERS_TO_INITIALIZE`

## Запуск CLI-утилиты

Первоначально установить зависимости gem'а:
```shell
bundle install
```

Далее можно выполнять запуск утилиты:
```shell
bundle exec exe/payment_integration_generator generate NovaPay --file payment_integration_generator/lib/configs_examples/provider_api.yaml --output_folder /path
```

Так же возможно выполнить сборку и установку gem'а, чтобы использовать его в системе. Для этого на системе с установленным Ruby >3.0 необходимо выполнить:
```
gem build payment_integration_generator.gemspec
```

Будет получен файл формата `payment_integration_generator-1.0.0.gem`. Необходимо установить локально собранный gem:
```
gem install payment_integration_generator-1.0.0.gem
```

После чего в системе можно будет обращаться к утилите:
```
payment_integration_generator generate NovaPay --file payment_integration_generator/lib/configs_examples/provider_api.yaml --output_folder /path
```

Так же собранный gem может быть опубликован в хранилище артефактов и устанавливаться пользователями с использованием Gemfile
