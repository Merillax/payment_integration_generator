# Payment Integration Generator

Библиотека для генерации интеграций с платёжными провайдерами. Она создаёт начальную структуру платёжной интеграции на основе переданной
OpenAPI-спецификации.

Библиотека работает через CLI.
В результате генерируются Ruby-сервис интеграции `example_service.rb`, документация `INTEGRATION.md`, fixtures `fixtures.json`.

## Требования

- Ruby 3.2 или новее;
- OpenAPI 3-спецификация в формате YAML или JSON;
- Bundler.

## Установка

```shell
bundle install
```

## Использование через командную строку

```shell
bundle exec exe/payment_integration_generator generate ИМЯ_ИНТЕГРАЦИИ [ОПЦИИ]
```

Для локального файла:

```shell
bundle exec exe/payment_integration_generator generate TestIntegration \
  --file /path/to/openapi.yaml
```

Для спецификации по URL:

```shell
bundle exec exe/payment_integration_generator generate TestIntegration \
  --url https://example.com/openapi.yaml
```

Необходимо указать ровно один из параметров: `--file` или `--url`.

### Параметры командной строки

| Параметр | Короткая форма | Назначение |
| --- | --- | --- |
| `--file PATH` | `-f` | Прочитать OpenAPI-спецификацию из локального файла. |
| `--url URL` | `-u` | Прочитать OpenAPI-спецификацию по URL. |
| `--output-folder PATH` | `-o` | Сохранить все сгенерированные файлы в указанную директорию. |
| `--payload-mapping-resolver PATH` | `-r` | Загрузить пользовательский resolver маппинга из Ruby-файла. |

Имя интеграции указывается как обязательный позиционный параметр. Имена в
snake_case и kebab-case по возможности преобразуются в PascalCase.

### Интерактивный выбор операций

Для каждой операции генератор показывает автоматически (методов весов) найденный вариант и
просит его подтвердить. Можно ввести:

- `YES` — принять найденную операцию;
- `ToDo` — оставить операцию для ручной реализации;
- `method path` — выполнить поиск по другому методу и пути, например `post /payouts`. (если пользователь знает какой метод ему нужен)

## Сгенерированные файлы

По умолчанию файлы сохраняются в:

```text
lib/integrations/<integration_name>_service.rb
lib/integrations/INTEGRATION.md
lib/integrations/fixtures.json
```

Директорию можно изменить с помощью `--output-folder`.

## Генерация payload

`PayloadMappingResolver` сопоставляет поля схемы запроса с со значения из `operation`. `PayloadBuilderGenerator` использует
этот маппинг для генерации `build_payout_payload`.

Например, поле `Amount` может быть сгенерировано так:

```ruby
Amount: (operation.amount * 100).to_i
```

Перед сопоставлением имена полей нормализуются. Регистр, подчёркивания и дефисы
не учитываются, поэтому `Amount`, `amount` и `AMOUNT` считаются одним полем.
Для вложенных полей сначала проверяется полный путь.

Если правило не найдено, поле сохраняется в payload и помечается для проверки:

```ruby
OrderId: nil # TODO: no matching mapping rule for OrderId
```

Сгенерированный код остаётся валидным Ruby и может быть дополнен вручную.

## Пользовательские правила маппинга

Создайте наследника resolver’а и переопределите `mapping_rules`. Используйте
`super.merge`, чтобы сохранить стандартные правила и добавить правила
конкретного провайдера:

```ruby
class TbankPayloadMappingResolver < PaymentIntegrationGenerator::PayloadMappingResolver
  def mapping_rules
    super.merge(
      "PaymentId" => "operation.id",
      "InfoEmail" => "operation.email",
      "DATA.threeDSCompInd" => "'Y'"
    )
  end
end
```

### Пользовательский resolver через CLI

Сохраните класс в файле, имя которого соответствует имени класса в snake_case.
Например, файл `tbank_payload_mapping_resolver.rb` должен содержать класс
`TbankPayloadMappingResolver`.

```shell
bundle exec exe/payment_integration_generator generate Tbank \
  --file /path/to/openapi.yaml \
  --payload-mapping-resolver /path/to/tbank_payload_mapping_resolver.rb
```

Пользовательский класс должен наследоваться от
`PaymentIntegrationGenerator::PayloadMappingResolver`.

Если пользовательский resolver не передан, используется стандартный
`PayloadMappingResolver`.

## Ручная настройка операций

Вариант `ToDo` можно выбрать для любой операции, которую генератор предлагает
подтвердить: `create_request`, `fetch_status` или `process_callback`. Это
означает, что автоматически найденную операцию нельзя использовать без
ручной проверки и настройки соответствующей части интеграции.

Для `create_request` дополнительно становится неизвестной схема тела запроса.
В этом случае генератор не строит payload автоматически, а создаёт заготовку:

```ruby
def build_payout_payload(operation)
  # TODO: implement payload mapping manually
  {}
end
```

Для `fetch_status` и `process_callback` необходимо вручную проверить выбранный
endpoint, параметры запроса, формат ответа и callback payload.

В сгенерированный метод также добавляются подсказки:

```ruby
# To customize field mappings, override PayloadMappingResolver#mapping_rules.
# Review fields marked with TODO before using this integration.
```

## Сообщения CLI

Информационные сообщения, предупреждения и ошибки CLI выводятся на английском
языке. Например:

```text
Generating TestIntegration integration based on OpenAPI specification...
Done!
Error: --file or --url must be specified
```

Сообщения об ошибках OpenAPI-спецификации также выводятся на английском языке.

## Справка

```shell
bundle exec exe/payment_integration_generator help
bundle exec exe/payment_integration_generator help generate
```
