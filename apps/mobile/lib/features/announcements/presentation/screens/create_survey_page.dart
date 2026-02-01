import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/announcements/data/repositories/announcements_repository.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';

/// Survey question types
enum SurveyQuestionType {
  text('text', 'Metin Yanıtı', Icons.short_text),
  singleChoice('single_choice', 'Tek Seçim', Icons.radio_button_checked),
  multipleChoice('multiple_choice', 'Çoklu Seçim', Icons.check_box),
  rating('rating', 'Puan (1-5)', Icons.star),
  yesNo('yes_no', 'Evet/Hayır', Icons.toggle_on);

  const SurveyQuestionType(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

/// Target scope options
enum TargetScope {
  myBranch('my_branch', 'Kendi Şubem'),
  myBranches('my_branches', 'Bölgemdeki Tüm Şubeler'),
  selectedBranches('selected_branches', 'Seçili Şubeler');

  const TargetScope(this.value, this.label);
  final String value;
  final String label;
}

/// Question model
class SurveyQuestion {
  SurveyQuestion({
    required this.questionText,
    this.questionType = SurveyQuestionType.text,
    this.options = const [],
    this.required = true,
  });

  String questionText;
  SurveyQuestionType questionType;
  List<String> options;
  bool required;

  Map<String, dynamic> toJson() => {
        'question_text': questionText,
        'question_type': questionType.value,
        'options': questionType == SurveyQuestionType.singleChoice ||
                questionType == SurveyQuestionType.multipleChoice
            ? options
            : null,
        'required': required,
      };
}

class CreateSurveyPage extends ConsumerStatefulWidget {
  const CreateSurveyPage({super.key});

  @override
  ConsumerState<CreateSurveyPage> createState() => _CreateSurveyPageState();
}

class _CreateSurveyPageState extends ConsumerState<CreateSurveyPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _summaryController = TextEditingController();

  bool _isLoading = false;
  bool _managersOnly = false;
  DateTime? _expiresAt;
  TargetScope _targetScope = TargetScope.myBranch;
  final List<String> _selectedBranchIds = [];
  List<Map<String, dynamic>> _availableBranches = [];
  String? _userRole;
  final List<SurveyQuestion> _questions = [
    SurveyQuestion(questionText: ''),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndBranches();
  }

  Future<void> _loadUserRoleAndBranches() async {
    final authState = ref.read(authProvider);
    authState.whenOrNull(
      authenticated: (user) {
        setState(() {
          _userRole = user.role;
          if (user.role == 'sube_muduru') {
            _targetScope = TargetScope.myBranch;
          } else if (user.role == 'bolge_muduru') {
            _targetScope = TargetScope.myBranches;
          }
        });
      },
    );

    try {
      final repo = ref.read(announcementsRepositoryProvider);
      final branches = await repo.getAvailableBranches();
      if (mounted) {
        setState(() {
          _availableBranches = branches;
        });
      }
    } catch (e) {
      debugPrint('Şubeler yüklenemedi: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  List<TargetScope> get _availableScopes {
    if (_userRole == 'sube_muduru') {
      return [TargetScope.myBranch];
    } else if (_userRole == 'bolge_muduru') {
      return [
        TargetScope.myBranches,
        TargetScope.selectedBranches,
      ];
    }
    return TargetScope.values;
  }

  void _addQuestion() {
    setState(() {
      _questions.add(SurveyQuestion(questionText: ''));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate questions
    for (var i = 0; i < _questions.length; i++) {
      if (_questions[i].questionText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru ${i + 1} boş olamaz'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if ((_questions[i].questionType == SurveyQuestionType.singleChoice ||
              _questions[i].questionType ==
                  SurveyQuestionType.multipleChoice) &&
          _questions[i].options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Soru ${i + 1} için en az 2 seçenek gerekli'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(announcementsRepositoryProvider);

      List<String>? targetBranches;
      if (_targetScope == TargetScope.selectedBranches) {
        targetBranches = _selectedBranchIds;
      }

      await repo.createSurvey(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        summary: _summaryController.text.trim().isNotEmpty
            ? _summaryController.text.trim()
            : null,
        targetScope: _targetScope.value,
        targetBranches: targetBranches,
        managersOnly: _managersOnly,
        expiresAt: _expiresAt,
        questions: _questions.map((q) => q.toJson()).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anket başarıyla oluşturuldu'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _expiresAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Anket'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Yayınla'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Anket Başlığı *',
                hintText: 'Anket başlığını girin',
                prefixIcon: Icon(Icons.poll),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Summary
            TextFormField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Özet (İsteğe bağlı)',
                hintText: 'Kısa bir özet...',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Content
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Açıklama *',
                hintText: 'Anket hakkında açıklama...',
                prefixIcon: Icon(Icons.article),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Açıklama zorunludur';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Questions Section
            Text(
              'Sorular',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ..._questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _buildQuestionCard(index, question, colorScheme);
            }),

            // Add Question Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: OutlinedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('Soru Ekle'),
              ),
            ),
            const SizedBox(height: 24),

            // Target Scope
            Text(
              'Hedef Kitle',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableScopes.map((scope) {
                return ChoiceChip(
                  label: Text(scope.label),
                  selected: _targetScope == scope,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _targetScope = scope);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Branch Selection (if selected_branches)
            if (_targetScope == TargetScope.selectedBranches) ...[
              Text(
                'Şube Seçimi',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_availableBranches.isEmpty)
                const Center(child: Text('Yükleniyor...'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableBranches.map((branch) {
                    final id = branch['id'] as String;
                    final name = branch['name'] as String;
                    final isSelected = _selectedBranchIds.contains(id);
                    return FilterChip(
                      label: Text(name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedBranchIds.add(id);
                          } else {
                            _selectedBranchIds.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
            ],

            // Options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seçenekler',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Managers Only
                    SwitchListTile(
                      title: const Text('Sadece Müdürlere'),
                      subtitle: const Text('Sadece yöneticiler görebilir'),
                      value: _managersOnly,
                      onChanged: (value) {
                        setState(() => _managersOnly = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),

                    // Expiry Date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Son Katılım Tarihi'),
                      subtitle: Text(
                        _expiresAt != null
                            ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                            : 'Sınırsız',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_expiresAt != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() => _expiresAt = null);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectExpiryDate,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
      int index, SurveyQuestion question, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Soru ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeQuestion(index),
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Text
            TextFormField(
              initialValue: question.questionText,
              decoration: const InputDecoration(
                labelText: 'Soru metni',
                hintText: 'Soruyu yazın...',
              ),
              onChanged: (value) {
                question.questionText = value;
              },
            ),
            const SizedBox(height: 12),

            // Question Type
            DropdownButtonFormField<SurveyQuestionType>(
              value: question.questionType,
              decoration: const InputDecoration(
                labelText: 'Soru Tipi',
              ),
              items: SurveyQuestionType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(type.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    question.questionType = value;
                    if (value == SurveyQuestionType.singleChoice ||
                        value == SurveyQuestionType.multipleChoice) {
                      if (question.options.isEmpty) {
                        question.options = ['', ''];
                      }
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Options (for choice questions)
            if (question.questionType == SurveyQuestionType.singleChoice ||
                question.questionType == SurveyQuestionType.multipleChoice) ...[
              const Text(
                'Seçenekler',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...question.options.asMap().entries.map((entry) {
                final optIndex = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: entry.value,
                          decoration: InputDecoration(
                            labelText: 'Seçenek ${optIndex + 1}',
                            isDense: true,
                          ),
                          onChanged: (value) {
                            question.options[optIndex] = value;
                          },
                        ),
                      ),
                      if (question.options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            setState(() {
                              question.options.removeAt(optIndex);
                            });
                          },
                          color: Colors.red,
                          iconSize: 20,
                        ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    question.options.add('');
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Seçenek Ekle'),
              ),
            ],

            // Required toggle
            SwitchListTile(
              title: const Text('Zorunlu'),
              value: question.required,
              onChanged: (value) {
                setState(() {
                  question.required = value;
                });
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
