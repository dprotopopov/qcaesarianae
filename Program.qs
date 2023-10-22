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
        let i = ResultArrayAsInt(results);
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
        let m = 2^n;
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
            let m = 2^n;
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
