% 1. Configuration
portCOM = "COM23";       % Remplacez par votre port COM (ex: "COM3", "COM4")
baudRate = 115200;      % Mettez la même vitesse que dans le STM32
fenetreGlissante = 100; % Nombre de points affichés à l'écran

% 2. Connexion Série
s = serialport(portCOM, baudRate);
configureTerminator(s, "CR/LF");
flush(s);

% 3. Configuration de la Figure MATLAB
fig = figure('Name', 'Acquisition STM32 en Temps Réel', 'Color', 'w');
ax = axes('Parent', fig);
hold(ax, 'on');
grid(ax, 'on');
xlabel(ax, 'Échantillons');
ylabel(ax, 'Valeur brute');
title(ax, 'Accéléromètre / Capteur - Temps Réel');

% Lignes animées pour X, Y et Z
hX = animatedline('Color', 'r', 'LineWidth', 1.2, 'DisplayName', 'Axe X');
hY = animatedline('Color', 'g', 'LineWidth', 1.2, 'DisplayName', 'Axe Y');
hZ = animatedline('Color', 'b', 'LineWidth', 1.2, 'DisplayName', 'Axe Z');
legend(ax, 'Location', 'northeast');

disp('Lecture en temps réel lancée. Fermez la fenêtre du graphique pour arrêter.');

% 4. Boucle de lecture et d'affichage
t = 0;
cleanupObj = onCleanup(@() clear('s')); % Libère le port COM en cas d'arrêt

while ishandle(fig)
    try
        % Lecture d'une ligne transmise par le STM32 (ex: "11, -25, 1025")
        dataLine = readline(s);
       
        % Conversion du texte en tableau de 3 nombres
        valeurs = str2num(dataLine); %#ok<ST2NM>
       
        % Si la ligne contient bien 3 valeurs (X, Y, Z)
        if length(valeurs) == 3
            t = t + 1;
           
            % Ajout des nouveaux points sur le graphique
            addpoints(hX, t, valeurs(1));
            addpoints(hY, t, valeurs(2));
            addpoints(hZ, t, valeurs(3));
           
            % Défilement du graphique (fenêtre glissante)
            if t > fenetreGlissante
                xlim(ax, [t - fenetreGlissante, t]);
            else
                xlim(ax, [1, fenetreGlissante]);
            end
           
            % Rafraîchissement optimisé de l'affichage
            drawnow limitrate;
        end
    catch
        % Ignore les lignes mal reçues pendant la transmission
        continue;
    end
end

disp('Acquisition arrêtée.');