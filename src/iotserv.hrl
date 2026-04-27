%% Структура IoT-устройства
-record(device, {
    id,          %% ID устройства
    name,        %% Название
    address,     %% Адрес установки
    temperature, %% Температура
    indicators = [] %% Список показателей
}).
