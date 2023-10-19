# Изучаем Q#. Алгоритм Гровера. Не будите спящего Цезаря!
~~_Криптохомячкам посвящается ..._~~

Алгоритм Гровера представляет собой обобщённый, независящей от конкретной задачи поиск, функция которого представляет "чёрный ящик" **f: {0,1}^n to {0,1}^n**, для которой известно, что **EXIST!w:f(w)=a**, где **a** - заданное значение.

Считаем, что для **f** и заданного **a** можно построить оракул **Uf: { |w> to |1>, |x> to |0> if |x> != |w> }**

## Алгоритм Гровера достаточно прост 
1. Задаём в регистре (массиве кубитов) начальное значение **H|0>**
2. Повторяем несколько раз (исходя из оценки) пару трансформаций над регистром
- Отражение от решения **Uw: { |w> to -|w>, |x> to |x> if |x> !=|w> }** или **Uw = I-2|w><w|**
- Отражение от **s=H|0>** **Us = 2|s><s|-I**
3. Забираем нужное решение из регистра (с большой долей вероятности, что оно правильное)

![Не будите спящего Цезаря!](https://sun9-5.userapi.com/impf/8dkGtYMVz7Vp8FiQl9qe3G8nDz4owqMw1X2dgg/oD4e7JU9tJ8.jpg?size=1024x576&quality=96&sign=1adc52e8b373010bf6be14fdbac02816&c_uniq_tag=XmoAV_G83m5lyOS-5XKyhJLMA-se5ihtjgd1dS9f0G0&type=album)

Применим этот алгоритм для решения задачи нахождения ключа шифра Цезаря ...

-------------------------------------------------------------------

Шифр Цезаря - это один из моноалфавитных шифров, где алфавит может быть представлен как кольцо вычетов **Z|m**.

И, если ключ **key** - число из **0..(m-1)**, а **x(i)** - где **i=0..(l-1)** и являются числами из **0..(m-1)**, то
**y(i) = (x(i)+key) mod m** - является шифротекстом.

Соответственно, **x(i) = (y(i) - key) mod m = (y(i) + (m-key)) mod m** - является процедурой расшифрования.

## Постановка задачи
Предположим, что в открытом тексте некоторые символы из **Z|m** встречаются редко или не встречаются совсем.

### Что будет означать данный факт? 
То что имея шифротекст **y(i)** мы можем выполнить следующие действия
1. будем перебирать все возможные значения ключа **key**
2. для данного ключа получим открытый текст **x(i)**
3. у данного открытого текста **x(i)** подсчитаем количество "неправильных" символов - то есть тех - которые не встречаются совсем (или встречаются очень редко)
4. среди всех ключей выберем тот - у которого полученное количество "неправильных" символов равно ноль (или минимально)

Таким образом, по шифротексту, зная ограничения на символы открытого текста, мы методом грубой силы получим значение ключа шифра Цезаря.

Очевидно, что приведённый алгоритм является по своей сути реализацией следующей задачи
- Дано **Error|y:Z|m->N+0**
- Требуется найти такой **key**, что **Error(key)=0** (или **Error(key)<const**)

А это и есть условие для применения алгоритма Гровера

NB. Очевидно, что подобные рассуждения можно провести для любого блочного шифра как в режиме **ECB**, так и в режиме **CBC**

## Перейдём к реализации на Q#
Пусть **m=2^n** и про открытый текст известно, что старший разряд в двоичном представлении числа-символа открытого текста всегда равен 0

### Реализуем следующие методы
1. Метод арифметики над регистром из кубитов - увеличение значения на единицу, то есть трансформация **Inc:|k> to |k+1>**
```
    /// # Описание
    /// увеличение на единицу числового значения в массиве кубитов (рассматриваемых как регистр)
    /// то есть трансформация вида |k> -> |k+1>
    operation Inc(target: Qubit[]) : Unit is Ctl {
        let n = Length(target);
        for idx in 1..n {
            Controlled X(target[0..n-idx-1], target[n-idx]);
        } 
    }
```
2. Метод арифметики над регистром из кубитов - увеличение значения на заданную величину value, то есть трансформация **Add(value):|k> to |k+value>**
```
    /// # Описание
    /// увеличение на указанную величину числового значения в массиве кубитов (рассматриваемых как регистр)
    /// то есть трансформация вида |k> -> |k+value>
    operation Add(target: Qubit[], value: Int) : Unit {
        let n = Length(target);
        let bools = IntAsBoolArray(value, n);
        use (qubits) = (Qubit[2]) {
            for idx in 0..n-1 {
                let carry = qubits[idx%2];
                let next = qubits[1-(idx%2)];
                // вычисляем следующее значение флага переноса разряда
                if(bools[idx]) {
                    // next = carry*target[idx]^carry^target[idx] = carry|target[idx]
                    Controlled X([carry, target[idx]], next);
                    Controlled X([carry], next);
                    Controlled X([target[idx]], next);
                }
                else {
                    // next = carry*target[idx] = carry&target[idx]
                    Controlled X([carry, target[idx]], next);
                }
                
                // добавляем текушее значение флага переноса и добавляемого бита
                Controlled X([carry], target[idx]);
                if(bools[idx]) {
                    X(target[idx]);
                }
                Reset(carry);
            } 
            ResetAll(qubits);
        }
    }
```
3. Методы генерации случайного ключа и случайно последовательности открытого текста (с учётом введёного ограничения на символы открытого текста)
```
    /// # Описание
    /// генерация последовательности со случайными символами алфавита (с учётом ограничений)
    operation RandomPlain(n: Int, l: Int) : Int[] {
        mutable plain = [0, size = l];
        use qubits = Qubit[n-1] { // !!! здесь мы ограничили набор входных символов - только числа без старшего разряда
            for idx in 0..l-1 {
                ApplyToEach(H, qubits);
                set plain w/= idx <- Measure(qubits);
                ResetAll(qubits);
            }
        }
        return plain;
    }

    /// # Описание
    /// генерация случайного ключа
    operation RandomKey(n: Int) : Int {
        use qubits = Qubit[n] {
            ApplyToEach(H, qubits);
            let key = Measure(qubits);
            ResetAll(qubits);
            return key;
        }
    }
```
4. Метод шифрования шифром Цезаря
```
    /// # Описание
    /// получение шифрованного текста из открытого на указанном ключе (key)
    /// соответсвенно, для обратного преобазования используем эту же функцию, но с отрицательным ключем (-key)
    operation Encrypt(n: Int, plain: Int[], key: Int) : Int[] {
        let l = Length(plain);
        mutable m = 1;
        for i in 1..n {
            set m *= 2;
        }
        mutable cipher = [0, size = l];
        for idx in 0..l-1 {
            set cipher w/= idx <- (plain[idx]+key) % m;
        }
        return cipher;
    }

    /// # Описание
    /// вспомогательный метод для копирования значений массива кубитов
    operation Copy(source: Qubit[], target: Qubit[]) : Unit {
        let n = Length(source);
        for i in 0..(n-1) {
            Controlled X([source[i]], target[i]);
        }
    }

    /// # Описание
    /// реализация шифра цезаря (для одного символа) на кубитах
    /// то есть, для возможных вариантов ключа key имеем возможные варианты выхода
    /// и, соответственно, наоборот - при использовании отрицательного значения ключа (-key)
    /// получим возможные варианты открытого текста, для заданного шифросимвола
    operation EncryptChar(n: Int, ch: Int, cipher: Qubit[], key: Qubit[]) : Unit {
        Copy(key, cipher);
        Add(cipher, ch);
    } 
```
5. Метод подсчёта количества "неправильных" символов для заданного шифротекста и заданного ключа
```
    /// # Описание
    /// подсчёт количества "неправильных" символов, полученных в результате попытки дешифрования
    /// шифротекста в открытый текст на указанном ключе
    operation CountErrorsOnDecrypt(n: Int, cipher: Int[], key: Qubit[], error: Qubit[]) : Unit {
        // Для шифра Цезаря plain = cipher - key = chiper + (-key)
        // а поскольку мы реализовали только метод Add, то изменим знак числа key
        // key = -key = ~key+1
        ApplyToEach(X, key);
        Inc(key);

        use (plain) = (Qubit[n]) {
            for ch in cipher {
                EncryptChar(n, ch, plain, key);
                // поскольку мы ограничивали входные символы только числами без старшего разряда
                // то каждое наличие единицы в старшем разряде должно считаться ошибкой
                // найдём число таких ошибок в регистре error
                Controlled Inc([plain[n-1]], error);
                ResetAll(plain);
            }
        }

        ApplyToEach(X, key);
        Inc(key);
    }
```
6. Реализацию оракла - который выдаёт **|1>** если для опробываемого ключа количество "неправильных" символов равно 0
```
    /// # Описание
    /// реализация оракла, необходимого для алгоритма гровера
    /// соответственно, мы считаем, что правильное решение - это то, которое не имеет ошибок
    operation NoErrorOracle(n: Int, cipher: Int[], key: Qubit[], target: Qubit): Unit {
        let l = Length(cipher);
        let k = BitSizeI(l);
        
        use (error) = (Qubit[k]) {
            CountErrorsOnDecrypt(n, cipher, key, error);
            // очевидно, что если для error == 0, то это означает, что мы нашли нужный ключ
            // тогда, в соответствии с правилом построения оракула Uf(x,y)=(x,y^f(x)),
            // инвертируем последний кубит, если error == 0
            ApplyToEach(X, error);
            Controlled X(error, target);
            ResetAll(error);
        }
    }
```
7. Методы алгоритма Гровера (взято с https://learn.microsoft.com/ru-ru/azure/quantum/tutorial-qdk-grovers-search?tabs=tabid-visualstudio)
- Отражение от решения
```
    /// # Описание
    /// шаг для алгоритма гровера
    /// отражение от решения    
    operation ReflectAboutSolution(oracle : (Qubit[], Qubit) => Unit, register : Qubit[]) : Unit {
        use (target)=(Qubit()){
            within {
                X(target);
                H(target);
            }
            apply {
                oracle(register, target);
            }
        }
    }
```
- Отражение от **H|0>**
```
    /// # Описание
    /// шаг для алгоритма гровера
    /// отражение от H|0>
    operation ReflectAboutUniform(inputQubits : Qubit[]) : Unit {
        within {
            ApplyToEachA(H, inputQubits);
            ApplyToEachA(X, inputQubits);
        }
        apply {
            Controlled Z(Most(inputQubits), Tail(inputQubits));
        }
    }
```
- И, собственно, основной цикл алгоритма Гровера
```
    /// # Описание
    /// алгоритм гровера
    operation RunGroversSearch(register : Qubit[], oracle : (Qubit[], Qubit) => Unit, iterations : Int) : Unit {
        ApplyToEach(H, register);
        for _ in 1 .. iterations {
            ReflectAboutSolution(oracle, register);
            ReflectAboutUniform(register);
        }
    }
```

## Подготовим тест
1. Проверим правильность работы построенного оракла с помошью алгоритма грубой силы
```
            // проверка оракла
            // прогоним его через брутто-форс
            for i in 0..m-1 {
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    Add(qubits, i);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"BruteForce: {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"BruteForce: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
```
2. Запустим алгоритм Гровера в двух режимах:
- с рассчитанным количеством итераций до получения ответа
```
            // применяем алгоритм гровера
            // указываем точное число шагов у алгоритма
            set isSuccess = false;
            repeat {
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    let iterations = Round(PI()/4.0*Sqrt(IntAsDouble(m)));
                    RunGroversSearch(qubits, noErrorOracle, iterations);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"GroversSearch: iterations = {iterations} ... {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        set isSuccess = true;
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"GroversSearch: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
            until(isSuccess);
```
- с разными значениями количества итераций до получения ответа
```
            // применяем алгоритм гровера
            // точное число шагов у алгоритма мы не знаем (знаем только оценку)
            // поэтому запускаем с разными значениями итераций
            // Повторение итераций после groverIterations сопровождается снижением этой вероятности
            // вплоть до практически нулевой вероятности успеха на итерации 2*groverIterations.
            // После этого вероятность снова возрастает до итерации 3*groverIterations и т. д.
            // В практических приложениях обычно неизвестно, сколько решений имеет ваша задача, 
            // прежде чем вы решите ее. Эффективной стратегией для решения этой проблемы является 
            // "предположение" количества решений путем постепенного увеличения степени двойки (т. е. 1,2,4,8,...).
            // Одно из этих предположений будет достаточно близким для того, чтобы алгоритм нашел решение
            // со средним числом итераций около SQRT(2^n/S) 

            mutable currenIterations = 0;
            set isSuccess = false;
            repeat{
                set currenIterations = currenIterations+1;
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    RunGroversSearch(qubits, noErrorOracle, currenIterations);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"GroversSearch: iterations = {currenIterations} ... {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        set isSuccess = true;
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"GroversSearch: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
            until (isSuccess);
```

### Полный текст кода
```
namespace qcaesarianae {

    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Logical;
    open Microsoft.Quantum.Diagnostics;
    
    /// # Описание
    /// увеличение на единицу числового значения в массиве кубитов (рассматриваемых как регистр)
    /// то есть трансформация вида |k> -> |k+1>
    operation Inc(target: Qubit[]) : Unit is Ctl {
        let n = Length(target);
        for idx in 1..n {
            Controlled X(target[0..n-idx-1], target[n-idx]);
        } 
    }

    /// # Описание
    /// увеличение на указанную величину числового значения в массиве кубитов (рассматриваемых как регистр)
    /// то есть трансформация вида |k> -> |k+value>
    operation Add(target: Qubit[], value: Int) : Unit {
        let n = Length(target);
        let bools = IntAsBoolArray(value, n);
        use (qubits) = (Qubit[2]) {
            for idx in 0..n-1 {
                let carry = qubits[idx%2];
                let next = qubits[1-(idx%2)];
                // вычисляем следующее значение флага переноса разряда
                if(bools[idx]) {
                    // next = carry*target[idx]^carry^target[idx] = carry|target[idx]
                    Controlled X([carry, target[idx]], next);
                    Controlled X([carry], next);
                    Controlled X([target[idx]], next);
                }
                else {
                    // next = carry*target[idx] = carry&target[idx]
                    Controlled X([carry, target[idx]], next);
                }
                
                // добавляем текушее значение флага переноса и добавляемого бита
                Controlled X([carry], target[idx]);
                if(bools[idx]) {
                    X(target[idx]);
                }
                Reset(carry);
            } 
            ResetAll(qubits);
        }
    }
    
    /// # Описание
    /// измерение значений (коллапсирование) кубитов в массиве (который рассматриваем как один регистр)
    /// и возврат числа (равного полученной двоичной последовательности)
    operation Measure(qubits: Qubit[]) : Int {
        let results = ForEach(M, qubits);
        let bools = ResultArrayAsBoolArray(results);
        let i = BoolArrayAsInt(bools);
        return i;
    }

    /// # Описание
    /// генерация последовательности со случайными символами алфавита (с учётом ограничений)
    operation RandomPlain(n: Int, l: Int) : Int[] {
        mutable plain = [0, size = l];
        use qubits = Qubit[n-1] { // !!! здесь мы ограничили набор входных символов - только числа без старшего разряда
            for idx in 0..l-1 {
                ApplyToEach(H, qubits);
                set plain w/= idx <- Measure(qubits);
                ResetAll(qubits);
            }
        }
        return plain;
    }

    /// # Описание
    /// генерация случайного ключа
    operation RandomKey(n: Int) : Int {
        use qubits = Qubit[n] {
            ApplyToEach(H, qubits);
            let key = Measure(qubits);
            ResetAll(qubits);
            return key;
        }
    }

    /// # Описание
    /// получение шифрованного текста из открытого на указанном ключе (key)
    /// соответсвенно, для обратного преобазования используем эту же функцию, но с отрицательным ключем (-key)
    operation Encrypt(n: Int, plain: Int[], key: Int) : Int[] {
        let l = Length(plain);
        mutable m = 1;
        for i in 1..n {
            set m *= 2;
        }
        mutable cipher = [0, size = l];
        for idx in 0..l-1 {
            set cipher w/= idx <- (plain[idx]+key) % m;
        }
        return cipher;
    }

    /// # Описание
    /// вспомогательный метод для копирования значений массива кубитов
    operation Copy(source: Qubit[], target: Qubit[]) : Unit {
        let n = Length(source);
        for i in 0..(n-1) {
            Controlled X([source[i]], target[i]);
        }
    }

    /// # Описание
    /// реализация шифра цезаря (для одного символа) на кубитах
    /// то есть, для возможных вариантов ключа key имеем возможные варианты выхода
    /// и, соответственно, наоборот - при использовании отрицательного значения ключа (-key)
    /// получим возможные варианты открытого текста, для заданного шифросимвола
    operation EncryptChar(n: Int, ch: Int, cipher: Qubit[], key: Qubit[]) : Unit {
        Copy(key, cipher);
        Add(cipher, ch);
    } 

    /// # Описание
    /// подсчёт количества "неправильных" символов, полученных в результате попытки дешифрования
    /// шифротекста в открытый текст на указанном ключе
    operation CountErrorsOnDecrypt(n: Int, cipher: Int[], key: Qubit[], error: Qubit[]) : Unit {
        // Для шифра Цезаря plain = cipher - key = chiper + (-key)
        // а поскольку мы реализовали только метод Add, то изменим знак числа key
        // key = -key = ~key+1
        ApplyToEach(X, key);
        Inc(key);

        use (plain) = (Qubit[n]) {
            for ch in cipher {
                EncryptChar(n, ch, plain, key);
                // поскольку мы ограничивали входные символы только числами без старшего разряда
                // то каждое наличие единицы в старшем разряде должно считаться ошибкой
                // найдём число таких ошибок в регистре error
                Controlled Inc([plain[n-1]], error);
                ResetAll(plain);
            }
        }

        ApplyToEach(X, key);
        Inc(key);
    }

    /// # Описание
    /// реализация оракла, необходимого для алгоритма гровера
    /// соответственно, мы считаем, что правильное решение - это то, которое не имеет ошибок
    operation NoErrorOracle(n: Int, cipher: Int[], key: Qubit[], target: Qubit): Unit {
        let l = Length(cipher);
        let k = BitSizeI(l);
        
        use (error) = (Qubit[k]) {
            CountErrorsOnDecrypt(n, cipher, key, error);
            // очевидно, что если для error == 0, то это означает, что мы нашли нужный ключ
            // тогда, в соответствии с правилом построения оракула Uf(x,y)=(x,y^f(x)),
            // инвертируем последний кубит, если error == 0
            ApplyToEach(X, error);
            Controlled X(error, target);
            ResetAll(error);
        }
    }

    /// # Описание
    /// шаг для алгоритма гровера
    /// отражение от решения    
    operation ReflectAboutSolution(oracle : (Qubit[], Qubit) => Unit, register : Qubit[]) : Unit {
        use (target)=(Qubit()){
            within {
                X(target);
                H(target);
            }
            apply {
                oracle(register, target);
            }
        }
    }

    /// # Описание
    /// шаг для алгоритма гровера
    /// отражение от H|0>
    operation ReflectAboutUniform(inputQubits : Qubit[]) : Unit {
        within {
            ApplyToEachA(H, inputQubits);
            ApplyToEachA(X, inputQubits);
        }
        apply {
            Controlled Z(Most(inputQubits), Tail(inputQubits));
        }
    }

    /// # Описание
    /// алгоритм гровера
    operation RunGroversSearch(register : Qubit[], oracle : (Qubit[], Qubit) => Unit, iterations : Int) : Unit {
        ApplyToEach(H, register);
        for _ in 1 .. iterations {
            ReflectAboutSolution(oracle, register);
            ReflectAboutUniform(register);
        }
    }

    @EntryPoint()
    operation Main(n: Int, l: Int) : Unit {
        Message("Hello quantum world!");

        let tests = 1;
        for _ in 1..tests {
            mutable m = 1;
            for _ in 1..n {
                set m *= 2;
            }
            Message($"n = {n} ... l = {l} ... m = {m}");

            let key = RandomKey(n);
            let cipher = Encrypt(n, RandomPlain(n, l), key);
            Message($"key = {key} cipher = {cipher}");

            let noErrorOracle = NoErrorOracle(n, cipher, _, _);

            let groverIterations = Round(PI()/4.0*Sqrt(IntAsDouble(m)));
            Message($"GroversSearch: groverIterations = {groverIterations}?");

            mutable isSuccess = false;

            // применяем алгоритм гровера
            // указываем точное число шагов у алгоритма
            set isSuccess = false;
            repeat {
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    let iterations = Round(PI()/4.0*Sqrt(IntAsDouble(m)));
                    RunGroversSearch(qubits, noErrorOracle, iterations);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"GroversSearch: iterations = {iterations} ... {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        set isSuccess = true;
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"GroversSearch: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
            until(isSuccess);

            // применяем алгоритм гровера
            // точное число шагов у алгоритма мы не знаем (знаем только оценку)
            // поэтому запускаем с разными значениями итераций
            // Повторение итераций после groverIterations сопровождается снижением этой вероятности
            // вплоть до практически нулевой вероятности успеха на итерации 2*groverIterations.
            // После этого вероятность снова возрастает до итерации 3*groverIterations и т. д.
            // В практических приложениях обычно неизвестно, сколько решений имеет ваша задача, 
            // прежде чем вы решите ее. Эффективной стратегией для решения этой проблемы является 
            // "предположение" количества решений путем постепенного увеличения степени двойки (т. е. 1,2,4,8,...).
            // Одно из этих предположений будет достаточно близким для того, чтобы алгоритм нашел решение
            // со средним числом итераций около SQRT(2^n/S) 

            mutable currenIterations = 0;
            set isSuccess = false;
            repeat{
                set currenIterations = currenIterations+1;
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    RunGroversSearch(qubits, noErrorOracle, currenIterations);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"GroversSearch: iterations = {currenIterations} ... {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        set isSuccess = true;
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"GroversSearch: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
            until (isSuccess);

            // проверка оракла
            // прогоним его через брутто-форс
            for i in 0..m-1 {
                use (qubits, oracle) = (Qubit[n], Qubit()){
                    Add(qubits, i);
                    noErrorOracle(qubits, oracle);
                    let hacked = Measure(qubits);
                    Message($"BruteForce: {key}=={hacked} ... oracle = {M(oracle)}");
                    if(M(oracle)==One){
                        let plain = Encrypt(n, cipher, m-hacked);
                        Message($"BruteForce: Success!!! {key}=={hacked} ... plain = {plain}");
                    }
                    ResetAll(qubits);
                    Reset(oracle);
                }
            }
        }
    }
}
```

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
Алгоритм Гровера даёт оценку требуемого количества итераций как PI/4*SQRT(2^n/S), где S - количество возможных решений задачи.

NB. А вы точно уверены, что квантовых компов с архитектурой фон Неймановского типа не сделают(-ли) - ведь и про факторизацию чисел много говорили, что это технически невозможно и сложно ... хо-хо-хо ?

## Ссылки
- https://github.com/dprotopopov/qcaesarianae
- https://ru.wikipedia.org/wiki/Шифр_Цезаря
- https://ru.wikipedia.org/wiki/Алгоритм_Гровера
- https://learn.microsoft.com/ru-ru/azure/quantum/tutorial-qdk-grovers-search?tabs=tabid-visualstudio

