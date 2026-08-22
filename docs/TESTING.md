# Проверка FlowArrows

## 1. Визуальная проверка в Godot 4

1. Установить Godot 4.x.
2. Клонировать репозиторий и переключиться на ветку `feat/initial-game-design`.
3. Открыть `project.godot` через Godot Project Manager.
4. Нажать **F6/F5** или кнопку **Run Project**.

Ожидаемый результат для текущего прототипа:

- открывается вертикальное окно FlowArrows;
- видны три элемента A, B, C со стрелками направления;
- заблокированные элементы нельзя нажать;
- свободный элемент уезжает за край;
- после его удаления становятся доступны новые ходы;
- после удаления всех элементов появляется `Solved!`.

## 2. Headless smoke-тесты

Из корня проекта можно запускать тестовые сцены без GUI:

```bash
godot --headless --path . --script tests/core_solver_smoke.gd
```

и

```bash
godot --headless --path . --script tests/generator_validator_smoke.gd
```

Если всё хорошо, процесс завершится без assertion errors.

## 3. Что проверяем на каждом этапе

- Core: корректность legal moves, solver, validator, generator.
- Gameplay: взаимодействие, блокировки, анимации, победа.
- Mobile: экспорт Android APK и проверка на физическом устройстве.
- CI: позже добавим GitHub Actions, чтобы smoke-тесты запускались автоматически для каждого PR.
