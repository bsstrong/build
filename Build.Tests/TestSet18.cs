﻿using System;

namespace Build.Tests.TestSet18
{
    public interface IFactory<T>
    {
        T GetInstance();
    }

    public class Factory<T> : IFactory<T>
    {
        public Factory(Func<T> func) => Func = func;

        public Func<T> Func { get; }

        public T GetInstance() => Func();
    }

    public class Factory2<T> : IFactory<T>
    {
        public Factory2()
        {
        }

        public Factory2(Func<T> func) => Func = func;

        public Func<T> Func { get; }

        public T GetInstance() => Func();
    }

    public class Factory3<T>
    {
        public Factory3(Func<T> func) => Func = func;

        public object Func { get; }
    }

    public class Type
    {
    }
}