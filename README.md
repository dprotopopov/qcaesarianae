# Изучаем Q#. Алгоритм Гровера. Не будите спящего Цезаря!
~~_Криптохомячкам посвящается ..._~~\
Алгоритм Гровера представляет собой обобщённый, независящей от конкретной задачи поиск, функция которого представляет "чёрный ящик" f: {0,1}^n -> {0,1}^n, для которой известно, что EXIST!w:f(w)=a, где a - заданное значение.\
Считаем, что для f и заданного a можно построить оракул Uf: { w->1, x->0 if x!=w }
## Алгоритм Гровера достаточно прост 
1. Задаём в регистре (массиве кубитов) начальное значение H|0>
2. Повторяем несколько раз (исходя из оценки) пару трансформаций над регистром
- Отражение от решения Uw: { w->-w, x->x if x!=w } или Uw = I-2|w><w|
- Отражение от s=H|0> Us = 2|s><s|-I
3. Забираем нужное решение из регистра (с большой долей вероятности, что оно правильное)

![Не будите спящего Цезаря!](https://sun9-5.userapi.com/impf/8dkGtYMVz7Vp8FiQl9qe3G8nDz4owqMw1X2dgg/oD4e7JU9tJ8.jpg?size=1024x576&quality=96&sign=1adc52e8b373010bf6be14fdbac02816&c_uniq_tag=XmoAV_G83m5lyOS-5XKyhJLMA-se5ihtjgd1dS9f0G0&type=album)

Применим этот алгоритм для решения задачи нахождения ключа шифра Цезаря ...

-------------------------------------------------------------------

Шифр Цезаря - это один из моноалфавитных шифров, где алфавит может быть представлен как кольцо вычетов Z|m.\

И, если ключ key - число из 0..(m-1), а x(i) - где i=0..(l-1) и являются числами из 0..(m-1), то
y(i) = (x(i)+key) mod m - является шифротекстом.\

Соответственно, x(i) = (y(i) - key) mod m = (y(i) + (m-key)) mod m - является процедурой расшифрования.

## Постановка задачи
Предположим, что в открытом тексте некоторые символы из Z|m встречаются редко или не встречаются совсем.

### Что будет означать данный факт? 
То что имея шифротекст y(i) мы можем выполнить следующие действия
1. будем перебирать все возможные значения ключа key
2. для данного ключа получим открытый текст x(i)
3. у данного открытого текста x(i) подсчитаем количество "неправильных" символов - то есть тех - которые не встречаются совсем (или встречаются очень редко)
4. среди всех ключей выберем тот - у которого полученное количество "неправильных" символов равно ноль (или минимально)

Таким образом, по шифротексту, зная ограничения на символы открытого текста, мы методом грубой силы получим значение ключа шифра Цезаря.

Очевидно, что приведённый алгоритм является по своей сути реализацией следующей задачи
- Дано Error(y):Z|m->N
- Требуется найти такой key, что Error(key)=0

А это и есть условие для применения алгоритма Гровера\

NB. Очевидно, что подобные рассуждения можно провести для любого блочного шифра как в режиме ECB, так и в режиме CBC

## Перейдём к реализации на Q#
Пусть m=2^n и про открытый текст известно, что старший разряд в двоичном представлении числа-символа открытого текста всегда равен 0

### Реализуем следующие методы
1. Метод арифметики над регистром из кубитов - увеличение значения на единицу, то есть трансформация Inc:|k>->|k+1>
2. Метод арифметики над регистром из кубитов - увеличение значения на заданную величину value, то есть трансформация Add(value):|k>->|k+value>
3. Методы генерации случайного ключа и случайно последовательности открытого текста (с учётом введёного ограничения на символы открытого текста)
4. Метод шифрования шифром Цезаря
5. Метод подсчёта количества "неправильных" символов для заданного шифротекста и заданного ключа
6. Реализацию оракла - который выдаёт |1> если для опробоваемого ключа количество "неправильных" символов равно 0
7. Методы алгоритма Гровера (взято с https://learn.microsoft.com/ru-ru/azure/quantum/tutorial-qdk-grovers-search?tabs=tabid-visualstudio)
- Отражение от решения
- Отражение от H|0>
- И, собственно, основной цикл алгоритма Гровера

## Подготовим тест
1. Проверим правильность работы построенного оракла с помошью алгоритма грубой силы
2. Запустим алгоритм Гровера в двух режимах:
- с рассчитанным количеством итераций до получения ответа
- с разными значениями количества итераций до получения ответа

### И собственно, потестим ... 
```
PS C:\Projects\qcaesarianae> dotnet run -n 3 -l 32
Hello quantum world!
n = 3 ... l = 32 ... m = 8
key = 4 cipher = [6,4,6,6,6,7,6,5,4,4,4,7,4,7,6,4,7,7,6,7,5,6,4,6,6,7,7,5,4,7,6,4]
GroversSearch: groverIterations = 2?
GroversSearch: iterations = 2 ... 4==5 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==6 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==3 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==6 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==1 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==6 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==3 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==2 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==6 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==7 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==5 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==5 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==6 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==1 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==0 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==5 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==4 ... oracle = One
GroversSearch: Success!!! 4==4 ... plain = [2,0,2,2,2,3,2,1,0,0,0,3,0,3,2,0,3,3,2,3,1,2,0,2,2,3,3,1,0,3,2,0]
GroversSearch: iterations = 1 ... 4==1 ... oracle = Zero
GroversSearch: iterations = 2 ... 4==4 ... oracle = One
GroversSearch: Success!!! 4==4 ... plain = [2,0,2,2,2,3,2,1,0,0,0,3,0,3,2,0,3,3,2,3,1,2,0,2,2,3,3,1,0,3,2,0]
BruteForce: 4==0 ... oracle = Zero
BruteForce: 4==1 ... oracle = Zero
BruteForce: 4==2 ... oracle = Zero
BruteForce: 4==3 ... oracle = Zero
BruteForce: 4==4 ... oracle = One
BruteForce: Success!!! 4==4 ... plain = [2,0,2,2,2,3,2,1,0,0,0,3,0,3,2,0,3,3,2,3,1,2,0,2,2,3,3,1,0,3,2,0]
BruteForce: 4==5 ... oracle = Zero
BruteForce: 4==6 ... oracle = Zero
BruteForce: 4==7 ... oracle = Zero
```

## Итог
Алгоритм Гровера даёт оценку требуемого количества итераций как PI/4*SQRT(2^n/S), где S - количество возможных решений задачи.\
NB. А вы точно уверены, что квантовых компов с архитектурой фон Неймановского типа не сделают(-ли) - ведь и про факторизацию чисел много говорили, что это технически невозможно и сложно ... хо-хо-хо ?

## Ссылки
- https://github.com/dprotopopov/qcaesarianae
- https://ru.wikipedia.org/wiki/Шифр_Цезаря
- https://ru.wikipedia.org/wiki/Алгоритм_Гровера
- https://learn.microsoft.com/ru-ru/azure/quantum/tutorial-qdk-grovers-search?tabs=tabid-visualstudio

