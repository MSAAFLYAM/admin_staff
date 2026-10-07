// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Gestion du personnel';

  @override
  String get appShortName => 'ADMIN STAFF';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get add => 'Ajouter';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get confirm => 'Confirmer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get search => 'Rechercher';

  @override
  String get filter => 'Filtrer';

  @override
  String get filters => 'Filtres';

  @override
  String get apply => 'Appliquer';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get clear => 'Effacer';

  @override
  String get retry => 'Réessayer';

  @override
  String get refresh => 'Actualiser';

  @override
  String get all => 'Tous';

  @override
  String get none => 'Aucun';

  @override
  String get loading => 'Chargement…';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get noResultsHint => 'Modifiez les mots de recherche ou les filtres.';

  @override
  String get unknown => 'Inconnu';

  @override
  String get optional => 'Facultatif';

  @override
  String get required => 'Obligatoire';

  @override
  String get from => 'Du';

  @override
  String get to => 'Au';

  @override
  String get date => 'Date';

  @override
  String get startDate => 'Date de début';

  @override
  String get endDate => 'Date de fin';

  @override
  String get returnDate => 'Date de retour';

  @override
  String get notes => 'Remarques';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get yesterday => 'Hier';

  @override
  String get tomorrow => 'Demain';

  @override
  String get count => 'Nombre';

  @override
  String get total => 'Total';

  @override
  String get actions => 'Actions';

  @override
  String get details => 'Détails';

  @override
  String get name => 'Nom';

  @override
  String get value => 'Valeur';

  @override
  String get status => 'Situation';

  @override
  String get active => 'Actif';

  @override
  String get inactive => 'Inactif';

  @override
  String get inactiveRecords => 'Enregistrements inactifs';

  @override
  String get showInactive => 'Afficher les inactifs';

  @override
  String get valueExists => 'Cette valeur existe déjà.';

  @override
  String get confirmDeleteTitle => 'Confirmer la suppression';

  @override
  String get confirmDeleteMessage =>
      'Êtes-vous sûr de vouloir supprimer ? Cette action est irréversible.';

  @override
  String get confirmArchiveTitle => 'Confirmer l\'archivage';

  @override
  String get confirmArchiveMessage =>
      'L\'enregistrement sera archivé tout en conservant tout son historique. Continuer ?';

  @override
  String get savedSuccessfully => 'Enregistré avec succès';

  @override
  String get deletedSuccessfully => 'Supprimé avec succès';

  @override
  String get unsavedChangesTitle => 'Modifications non enregistrées';

  @override
  String get unsavedChangesMessage =>
      'Vous avez des modifications non enregistrées. Quitter ?';

  @override
  String get navHome => 'Accueil';

  @override
  String get navEmployees => 'Personnel';

  @override
  String get navPermanence => 'Permanence';

  @override
  String get navLeaves => 'Congés';

  @override
  String get navSettings => 'Réglages';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get globalSearchHint => 'Rechercher un employé…';

  @override
  String get searchPlaceholder => 'Nom, matricule, section, grade…';

  @override
  String get totalEmployees => 'Total des employés';

  @override
  String get inService => 'En service';

  @override
  String get onLeave => 'En congé';

  @override
  String get sickLeave => 'Congé maladie';

  @override
  String get exceptionalLeave => 'Congé exceptionnel';

  @override
  String get suspended => 'Suspendus';

  @override
  String get retired => 'Retraités';

  @override
  String get archivedCount => 'Archivés';

  @override
  String get otherStatuses => 'Autres situations';

  @override
  String get todaysPermanence => 'Permanence du jour';

  @override
  String get todaysAlerts => 'Alertes du jour';

  @override
  String get leavesEndingToday => 'Congés finissant aujourd\'hui';

  @override
  String get leavesEndingTomorrow => 'Congés finissant demain';

  @override
  String get employeesReturningToday => 'Employés revenant aujourd\'hui';

  @override
  String get leavesEndingIn3Days => 'Congés finissant sous 3 jours';

  @override
  String todaysPermanenceCount(int count) {
    return '$count employé(s) en permanence aujourd\'hui';
  }

  @override
  String get noAlertsToday => 'Aucune alerte aujourd\'hui';

  @override
  String get noPermanenceToday => 'Aucune permanence pour ce jour';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get reports => 'Rapports';

  @override
  String get employeesTitle => 'Personnel';

  @override
  String get addEmployee => 'Ajouter un employé';

  @override
  String get editEmployee => 'Modifier l\'employé';

  @override
  String get employeeProfile => 'Dossier employé';

  @override
  String get employeeCard => 'Fiche employé';

  @override
  String get openProfile => 'Ouvrir le dossier';

  @override
  String get noEmployees => 'Aucun employé';

  @override
  String get noEmployeesHint =>
      'Importez un fichier CSV ou ajoutez un employé manuellement.';

  @override
  String searchResultsCount(int count) {
    return '$count résultat(s)';
  }

  @override
  String get tabInfo => 'Informations';

  @override
  String get tabStatus => 'Situation';

  @override
  String get tabLeaves => 'Congés';

  @override
  String get tabPermanence => 'Permanence';

  @override
  String get tabHistory => 'Historique';

  @override
  String get matricule => 'Matricule';

  @override
  String get ppr => 'PPR';

  @override
  String get nomAr => 'Nom (arabe)';

  @override
  String get prenomAr => 'Prénom (arabe)';

  @override
  String get nomFr => 'Nom';

  @override
  String get prenomFr => 'Prénom';

  @override
  String get fullNameAr => 'Nom en arabe';

  @override
  String get fullNameFr => 'Nom en français';

  @override
  String get section => 'Section';

  @override
  String get grade => 'Grade';

  @override
  String get fonction => 'Fonction';

  @override
  String get quality => 'Qualité';

  @override
  String get phone => 'Téléphone';

  @override
  String get mobilePhone => 'Téléphone mobile';

  @override
  String get currentStatus => 'Situation actuelle';

  @override
  String get chooseSection => 'Choisir une section';

  @override
  String get chooseGrade => 'Choisir un grade';

  @override
  String get chooseFunction => 'Choisir une fonction';

  @override
  String get chooseStatus => 'Choisir une situation';

  @override
  String get chooseEmployee => 'Choisir un employé';

  @override
  String get chooseLeaveType => 'Choisir un type de congé';

  @override
  String get chooseDate => 'Choisir une date';

  @override
  String get searchEmployee => 'Rechercher un employé…';

  @override
  String get errMatriculeRequired =>
      'Le matricule est obligatoire et ne peut pas être vide.';

  @override
  String get errMatriculeDuplicate =>
      'Ce matricule est déjà utilisé par un autre employé.';

  @override
  String get errPprDuplicate => 'Ce PPR est déjà utilisé par un autre employé.';

  @override
  String get errNameRequired => 'Saisissez le nom en arabe ou en français.';

  @override
  String get errFieldRequired => 'Ce champ est obligatoire.';

  @override
  String get errInvalidDate => 'Date invalide.';

  @override
  String get errEndBeforeStart =>
      'La date de fin doit être postérieure à la date de début.';

  @override
  String get errNegativeDuration => 'La durée doit être supérieure à zéro.';

  @override
  String get errInvalidHours => 'Valeur d\'heures invalide.';

  @override
  String get errInvalidPhone => 'Numéro de téléphone invalide.';

  @override
  String get errInvalidPpr => 'Valeur PPR invalide.';

  @override
  String get errEmptyFile => 'Le fichier est vide.';

  @override
  String errMissingColumn(String column) {
    return 'Impossible d\'importer : la colonne $column est introuvable.';
  }

  @override
  String errInvalidDateFormat(String value) {
    return 'Format de date inconnu : « $value »';
  }

  @override
  String get errUnknown =>
      'Une erreur inattendue s\'est produite. Consultez le journal technique.';

  @override
  String get errSaveFailed =>
      'Enregistrement impossible. Vérifiez les données saisies.';

  @override
  String get errImportFailed => 'Impossible d\'importer le fichier.';

  @override
  String get importTitle => 'Import CSV';

  @override
  String get importEmployees => 'Importer CSV personnel';

  @override
  String get importPermanence => 'Importer CSV permanence';

  @override
  String get selectFile => 'Sélectionner un fichier';

  @override
  String get fileName => 'Nom du fichier';

  @override
  String get preview => 'Aperçu';

  @override
  String get previewTitle => 'Aperçu de l\'import';

  @override
  String get columns => 'Colonnes';

  @override
  String get delimiter => 'Séparateur';

  @override
  String get encoding => 'Encodage';

  @override
  String get dateFormat => 'Format de date';

  @override
  String get detectedFormat => 'Format détecté';

  @override
  String get columnMapping => 'Correspondance des colonnes';

  @override
  String get csvColumn => 'Colonne CSV';

  @override
  String get mapsTo => 'Correspond à';

  @override
  String get ignoreColumn => 'Ignorer';

  @override
  String get totalRows => 'Total des enregistrements';

  @override
  String get newRows => 'Nouveaux enregistrements';

  @override
  String get updatedRows => 'Enregistrements à mettre à jour';

  @override
  String get duplicateRows => 'Enregistrements en double';

  @override
  String get errorRows => 'Enregistrements en erreur';

  @override
  String get validRows => 'Enregistrements acceptés';

  @override
  String get rejectedRows => 'Enregistrements rejetés';

  @override
  String get invalidRowsTitle => 'Lignes rejetées';

  @override
  String rowNumber(int n) {
    return 'Ligne $n';
  }

  @override
  String get confirmImport => 'Confirmer l\'import';

  @override
  String get importSucceeded => 'Import réussi';

  @override
  String get importRolledBack =>
      'Échec de l\'import, toutes les modifications ont été annulées.';

  @override
  String get unmatchedEmployees => 'Employés non associés';

  @override
  String get unmatchedHint =>
      'Ces employés sont introuvables dans la base. Ils ne seront pas créés automatiquement.';

  @override
  String matchedCount(int count) {
    return 'Associés : $count';
  }

  @override
  String unmatchedCount(int count) {
    return 'Non associés : $count';
  }

  @override
  String get importMode => 'Mode d\'import';

  @override
  String get modeAddWeek => 'Ajouter les nouveaux enregistrements';

  @override
  String get modeUpdateWeek => 'Mettre à jour les enregistrements existants';

  @override
  String get modeReplaceRange => 'Remplacer la période sélectionnée';

  @override
  String get replaceWarning =>
      'Remplacer les données de la période sélectionnée ? Les enregistrements existants seront supprimés d\'abord.';

  @override
  String get manualAddEmployee => 'Créer manuellement les employés manquants';

  @override
  String get skipUnmatched => 'Ignorer les enregistrements non associés';

  @override
  String get statusHistory => 'Historique des situations';

  @override
  String get addStatus => 'Ajouter une situation';

  @override
  String get editStatus => 'Modifier la situation';

  @override
  String get statusType => 'Type de situation';

  @override
  String get priority => 'Priorité';

  @override
  String get priorityHint =>
      'Plus la priorité est élevée, plus la situation domine en cas de chevauchement.';

  @override
  String get startDateRequired => 'La date de début est obligatoire.';

  @override
  String get noStatusHistory => 'Aucun historique de situation';

  @override
  String get noStatusHistoryHint =>
      'L\'historique apparaîtra ici après le premier changement de situation.';

  @override
  String get currentRecord => 'Enregistrement actuel';

  @override
  String get previousRecords => 'Historique précédent';

  @override
  String get terminalStatus => 'Situation finale';

  @override
  String get derivedStatus => 'Déduite du congé';

  @override
  String get changeStatus => 'Changer la situation';

  @override
  String get conflictDetected => 'Conflit détecté';

  @override
  String get conflictMessage =>
      'Cette période chevauche un enregistrement existant. La situation n\'a pas été appliquée automatiquement.';

  @override
  String get conflictPeriod => 'Période de chevauchement';

  @override
  String get existingRecord => 'Enregistrement existant';

  @override
  String get newRecord => 'Nouvel enregistrement';

  @override
  String get saveAnyway => 'Enregistrer quand même';

  @override
  String get leavesTitle => 'Congés';

  @override
  String get addLeave => 'Ajouter un congé';

  @override
  String get editLeave => 'Modifier le congé';

  @override
  String get leaveType => 'Type de congé';

  @override
  String get leaveTypes => 'Types de congés';

  @override
  String get addLeaveType => 'Ajouter un type de congé';

  @override
  String get editLeaveType => 'Modifier le type de congé';

  @override
  String get leavesCurrent => 'En cours';

  @override
  String get leavesUpcoming => 'À venir';

  @override
  String get leavesEnded => 'Terminés';

  @override
  String get noLeaves => 'Aucun congé en cours';

  @override
  String get noLeavesHint =>
      'Appuyez sur « Ajouter un congé » pour enregistrer un congé.';

  @override
  String get duration => 'Durée';

  @override
  String get unit => 'Unité';

  @override
  String get unitHours => 'Heures';

  @override
  String get unitDays => 'Jours';

  @override
  String get calculated => 'Calculé automatiquement';

  @override
  String get calculatedEnd => 'Date de fin calculée';

  @override
  String get calculatedReturn => 'Date de retour calculée';

  @override
  String get countStartDay => 'Inclure le jour de début';

  @override
  String get includeWeekends => 'Inclure les week-ends';

  @override
  String get includeHolidays => 'Inclure les jours fériés';

  @override
  String get dayCountMode => 'Mode de calcul des jours';

  @override
  String get modeCalendar => 'Jours calendaires';

  @override
  String get modeWorking => 'Jours ouvrables';

  @override
  String get returnDayMode => 'Mode de calcul du retour';

  @override
  String get returnImmediate => 'Immédiat (jour suivant)';

  @override
  String get returnNextWorking => 'Premier jour ouvrable';

  @override
  String get cancelLeave => 'Annuler le congé';

  @override
  String get leaveCancelled => 'Congé annulé';

  @override
  String get conflictLeaveOverlap => 'Un autre congé chevauche cette période.';

  @override
  String get businessDefaults => 'Valeurs par défaut modifiables';

  @override
  String get businessDefaultsHint =>
      'Toutes les durées et règles sont modifiables : aucune valeur codée en dur.';

  @override
  String get permanenceTitle => 'Permanence';

  @override
  String get addPermanence => 'Ajouter une permanence';

  @override
  String get editPermanence => 'Modifier la permanence';

  @override
  String get permanenceToday => 'Jour';

  @override
  String get permanenceWeek => 'Semaine';

  @override
  String get permanenceArchive => 'Archives';

  @override
  String get prevDay => 'Jour précédent';

  @override
  String get nextDay => 'Jour suivant';

  @override
  String get prevWeek => 'Semaine précédente';

  @override
  String get nextWeek => 'Semaine suivante';

  @override
  String get currentWeek => 'Semaine courante';

  @override
  String weekRange(String from, String to) {
    return '$from — $to';
  }

  @override
  String get noPermanence => 'Aucune permanence pour ce jour';

  @override
  String get noPermanenceWeek => 'Aucune permanence pour cette semaine';

  @override
  String get noPermanenceArchive => 'Aucun enregistrement de permanence';

  @override
  String get permanencier => 'Permanencier';

  @override
  String get schedule => 'Horaire';

  @override
  String get hpad => 'H-pad';

  @override
  String get startTime => 'Heure de début';

  @override
  String get endTime => 'Heure de fin';

  @override
  String get timeRange => 'Créneau';

  @override
  String get unlinkedRecord => 'Non associé à un employé';

  @override
  String get linkedTo => 'Associé à';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get sectionSecurity => 'Sécurité';

  @override
  String get sectionLanguage => 'Langue et apparence';

  @override
  String get sectionData => 'Données';

  @override
  String get sectionLeaves => 'Congés';

  @override
  String get sectionReferences => 'Sections, grades et fonctions';

  @override
  String get sectionBackup => 'Sauvegarde';

  @override
  String get sectionAbout => 'À propos';

  @override
  String get language => 'Langue';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'Français';

  @override
  String get darkMode => 'Mode sombre';

  @override
  String get changePin => 'Changer le code PIN';

  @override
  String get enablePin => 'Activer le code PIN';

  @override
  String get disablePin => 'Désactiver le code PIN';

  @override
  String get biometric => 'Biométrie';

  @override
  String get biometricEnable => 'Activer la biométrie';

  @override
  String get biometricUnavailable => 'Biométrie indisponible sur cet appareil';

  @override
  String get autoLock => 'Verrouillage automatique';

  @override
  String get autoLock1m => '1 minute';

  @override
  String get autoLock5m => '5 minutes';

  @override
  String get autoLock15m => '15 minutes';

  @override
  String get autoLockOff => 'Désactivé';

  @override
  String get createPin => 'Créez un code PIN';

  @override
  String get confirmPin => 'Confirmez le code PIN';

  @override
  String get wrongPin => 'Code PIN incorrect';

  @override
  String get pinMismatch => 'Les deux codes ne correspondent pas';

  @override
  String get pinTooShort => 'Le code doit contenir au moins 4 chiffres';

  @override
  String get sections => 'Sections';

  @override
  String get grades => 'Grades';

  @override
  String get functionsList => 'Fonctions';

  @override
  String get statusTypesList => 'Types de situations';

  @override
  String get holidays => 'Jours fériés';

  @override
  String get addSection => 'Ajouter une section';

  @override
  String get addGrade => 'Ajouter un grade';

  @override
  String get addFunction => 'Ajouter une fonction';

  @override
  String get addHoliday => 'Ajouter un jour férié';

  @override
  String get manage => 'Gérer';

  @override
  String get rename => 'Renommer';

  @override
  String get deactivate => 'Désactiver';

  @override
  String get reactivate => 'Réactiver';

  @override
  String get historyKept => 'Le renommage ne casse pas l\'historique.';

  @override
  String get noSections => 'Aucune section';

  @override
  String get noGrades => 'Aucun grade';

  @override
  String get noFunctions => 'Aucune fonction';

  @override
  String get noHolidays => 'Aucun jour férié';

  @override
  String get exportData => 'Exporter les données';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get importData => 'Importer des données';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get schemaVersion => 'Version du schéma';

  @override
  String get offlineNote =>
      'Cette application fonctionne entièrement en local et n\'envoie aucune donnée hors de l\'appareil.';

  @override
  String get createBackup => 'Créer une sauvegarde';

  @override
  String get restoreBackup => 'Restaurer une sauvegarde';

  @override
  String get backupCreated => 'Sauvegarde créée';

  @override
  String get backupEncrypted => 'Chiffrée (AES-256-GCM)';

  @override
  String get restoreTitle => 'Restaurer la sauvegarde';

  @override
  String get restoreWarning =>
      'La restauration remplacera toutes les données actuelles. Êtes-vous sûr ?';

  @override
  String get restoreSucceeded => 'Restauration réussie';

  @override
  String get backupCorrupt =>
      'Le fichier de sauvegarde est corrompu ou incompatible.';

  @override
  String get backupWrongKey =>
      'Déchiffrement impossible. Clé de restauration incorrecte.';

  @override
  String get backupChecksum =>
      'Échec de la vérification d\'intégrité (checksum).';

  @override
  String get backupVersionMismatch =>
      'Version de sauvegarde non prise en charge.';

  @override
  String get backupNoFile => 'Aucun fichier sélectionné.';

  @override
  String get backupIncludeAudit => 'Inclure le journal d\'audit';

  @override
  String get recentBackups => 'Dernières sauvegardes';

  @override
  String get reportEmployeesBySection => 'Employés par section';

  @override
  String get reportEmployeesByStatus => 'Employés par situation';

  @override
  String get reportCurrentLeaves => 'Congés en cours';

  @override
  String get reportEndedLeaves => 'Congés terminés';

  @override
  String get reportUpcomingLeaves => 'Congés à venir';

  @override
  String get reportPermanenceByDay => 'Permanenciers par jour';

  @override
  String get reportPermanenceByWeek => 'Permanenciers par semaine';

  @override
  String get reportEmployeesByGrade => 'Employés par grade';

  @override
  String get reportEmployeesByFunction => 'Employés par fonction';

  @override
  String get generateReport => 'Générer le rapport';

  @override
  String get exportResults => 'Exporter les résultats';

  @override
  String get auditLog => 'Journal d\'audit';

  @override
  String get auditCreated => 'Création';

  @override
  String get auditUpdated => 'Modification';

  @override
  String get auditDeleted => 'Suppression';

  @override
  String get auditImported => 'Import';

  @override
  String get auditRestored => 'Restauration';

  @override
  String get auditNoLogs => 'Aucun journal';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsEnable => 'Activer les notifications locales';

  @override
  String notifLeaveEndsTomorrow(String name) {
    return 'Le congé de $name se termine demain.';
  }

  @override
  String notifEmployeeReturnsToday(String name) {
    return 'L\'employé $name revient aujourd\'hui.';
  }

  @override
  String notifPermanenceCount(int count) {
    return 'Vous avez $count employé(s) en permanence aujourd\'hui.';
  }

  @override
  String get lockedTitle => 'Application verrouillée';

  @override
  String get unlockWithPin => 'Saisissez le code PIN';

  @override
  String get unlockWithBiometric => 'Utilisez l\'empreinte pour déverrouiller';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get forgotPin => 'Code oublié ?';

  @override
  String get forgotPinHint =>
      'Le code PIN enregistré ne peut pas être récupéré. Une réinstallation effacera les données, sauf si vous disposez d\'une sauvegarde.';
}
