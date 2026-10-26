# Practice_R

Відтворюване середовище для роботи з R у Linux x86_64: **R 4.5.3**, стандартні рекомендовані пакети, **renv 1.3.1**, компілятори C/C++/Fortran, `make` і `pkg-config`.

Репозиторій містить скрипти встановлення, зафіксовані залежності та перевірки середовища. Прикладного коду й тестів проєкту наразі немає.

## Встановлення

Потрібні Bash, Git, `curl` і `sha256sum`. Виконуйте команди з кореня цього репозиторію:

```bash
bash scripts/setup-r.sh
source scripts/activate-r.sh
R --no-save
```

Інсталятор перевіряє контрольну суму micromamba 2.9.0 і встановлює пакети з conda-forge за списком [environment/conda-linux-64.lock](environment/conda-linux-64.lock). Після встановлення запускаються перевірки середовища.

У хмарному середовищі інструменти, пакети й кеші зберігаються поза репозиторієм, у `/workspace/.practice-r-setup`. Micromamba також використовує службовий реєстр `~/.conda`. Для іншої Linux-машини можна вибрати власний каталог:

```bash
export PRACTICE_R_SETUP_ROOT="$HOME/.local/share/practice-r"
bash scripts/setup-r.sh
source scripts/activate-r.sh
```

Зберігайте те саме значення `PRACTICE_R_SETUP_ROOT` під час наступних запусків. У кожній новій оболонці Bash виконуйте `source scripts/activate-r.sh`: це налаштовує R, компілятори, бібліотеку користувацьких пакетів і кеші. Для запуску власного скрипту використовуйте `Rscript шлях/до/скрипту.R`.

## Перевірка

```bash
source scripts/activate-r.sh
Rscript --vanilla scripts/check-r.R
bash scripts/check-native.sh
```

Очікуваний результат — **5/5 перевірок R** і **3/3 перевірок розширень**:

- лінійна регресія та довірчі інтервали;
- запис і читання CSV з українським текстом;
- розв'язання системи зі sparse-матрицею пакета `Matrix`;
- створення PNG-графіка без графічного інтерфейсу;
- завантаження `renv`;
- збирання, завантаження й виклик розширень на C, C++ і Fortran.

Ці перевірки підтверджують роботу інструментів середовища. Вони не замінюють тести майбутнього проєкту.

## Мережевий доступ

Для встановлення потрібен HTTPS-доступ до `github.com`, `release-assets.githubusercontent.com` і `conda.anaconda.org`. Для додаткових пакетів із CRAN дозвольте `cloud.r-project.org` у мережевих налаштуваннях середовища:

```r
install.packages("назва_пакета", repos = "https://cloud.r-project.org")
```

У Codex зміни мережевої політики та інструкції запуску застосовуються через налаштування хмарного середовища. Збереження файлів у GitHub саме по собі не застосовує й не публікує ці налаштування.

## Файли

- [scripts/setup-r.sh](scripts/setup-r.sh) — встановлення та перевірка середовища.
- [scripts/activate-r.sh](scripts/activate-r.sh) — активація для поточної оболонки Bash.
- [scripts/check-r.R](scripts/check-r.R) — перевірки R.
- [scripts/check-native.sh](scripts/check-native.sh) — перевірки компіляторів і розширень.
- [environment/conda-linux-64.lock](environment/conda-linux-64.lock) — точні версії залежностей із контрольними сумами для Linux x86_64.
- [environment/start.md](environment/start.md) — інструкції запуску для хмарного середовища.

Встановлені бінарні файли, кеші та журнали не входять до Git: середовище відтворюється за цими скриптами й списком залежностей.
