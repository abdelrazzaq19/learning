import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:online_cource_app/Model/course_model.dart';
import 'package:online_cource_app/data/course_repository.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CourseRepository _repository = CourseRepository();

  String _cover = '';
  String _title = '';
  String _duration = '';
  // Previously missing from the form, so every admin-created course silently
  // took the model defaults (and used to cost 1400).
  String _description = '';
  String _category = 'General';
  double _price = 0;
  List<String> _instructors = [];
  String _tempInstructor = '';

  void _addCourse() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        // Show loading indicator
        EasyLoading.show(status: 'Adding course...');

        // Going through the repository keeps the searchable `titleLower`
        // field and the model's defaults consistent with the rest of the app.
        await _repository.createCourse(CourseModel(
          cover: _cover,
          title: _title,
          duration: _duration,
          instructors: _instructors,
          description: _description.isEmpty
              ? 'No description available'
              : _description,
          category: _category.isEmpty ? 'General' : _category,
          price: _price,
        ));

        // Hide loading indicator
        EasyLoading.dismiss();

        if (!mounted) return;
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course added successfully!')),
        );

        // Clear form
        _formKey.currentState!.reset();
        setState(() {
          _instructors = [];
        });
      } catch (e) {
        // Hide loading indicator
        EasyLoading.dismiss();

        if (!mounted) return;
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add course: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Course')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image URL Input
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Cover Image URL',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a cover image URL';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _cover = value!;
                  },
                ),
                const SizedBox(height: 20),

                // Course Title Input
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Course Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a course title';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _title = value!;
                  },
                ),
                const SizedBox(height: 20),

                // Course Duration Input
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the duration';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _duration = value!;
                  },
                ),
                const SizedBox(height: 20),

                // Category Input
                TextFormField(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    helperText: 'Used by search and the category filter',
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (value) => _category = value?.trim() ?? 'General',
                ),
                const SizedBox(height: 20),

                // Price Input
                TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (BDT)',
                    helperText: '0 marks the course as free',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (double.tryParse(value.trim()) == null) {
                      return 'Enter a number';
                    }
                    return null;
                  },
                  onSaved: (value) =>
                      _price = double.tryParse(value?.trim() ?? '') ?? 0,
                ),
                const SizedBox(height: 20),

                // Description Input
                TextFormField(
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (value) => _description = value?.trim() ?? '',
                ),
                const SizedBox(height: 20),

                // Instructor Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ..._instructors.map(
                      (instructor) => ListTile(
                        title: Text(instructor),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _instructors.remove(instructor);
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Add Instructor',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _tempInstructor = value;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: () {
                            if (_tempInstructor.isNotEmpty) {
                              setState(() {
                                _instructors.add(_tempInstructor);
                                _tempInstructor = '';
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Add Course Button
                ElevatedButton(
                  onPressed: _addCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  child: const Text('Add Course'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
