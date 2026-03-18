import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

class LocationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Function(double lat, double lng)? onSelected;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const LocationAutocomplete({
    Key? key,
    required this.controller,
    required this.label,
    required this.icon,
    this.onSelected,
    this.suffix,
    this.validator,
  }) : super(key: key);

  @override
  _LocationAutocompleteState createState() => _LocationAutocompleteState();
}

class _LocationAutocompleteState extends State<LocationAutocomplete> {
  static const Color _primary = Color(0xff113F67);
  List<dynamic> _suggestions = [];
  bool _isLoading = false;

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() { _suggestions = []; _isLoading = false; });
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final url = Uri.parse("https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5");
      final response = await http.get(url, headers: {'User-Agent': 'RideMatchApp/1.0'});
      if (response.statusCode == 200) {
        setState(() {
          _suggestions = json.decode(response.body);
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<dynamic>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<dynamic>.empty();
        }
        await _fetchSuggestions(textEditingValue.text);
        return _suggestions;
      },
      displayStringForOption: (option) => option['display_name'] ?? '',
      onSelected: (option) {
        final lat = double.tryParse(option['lat'].toString()) ?? 0.0;
        final lng = double.tryParse(option['lon'].toString()) ?? 0.0;
        if (widget.onSelected != null) {
          widget.onSelected!(lat, lng);
        }
        widget.controller.text = option['display_name'];
      },
      fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
        // Initialize once to match external controller
        if (fieldTextEditingController.text != widget.controller.text && !fieldFocusNode.hasFocus) {
             fieldTextEditingController.text = widget.controller.text;
        }

        fieldTextEditingController.addListener(() {
          widget.controller.text = fieldTextEditingController.text;
        });

        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          onFieldSubmitted: (String value) {
            onFieldSubmitted();
          },
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: GoogleFonts.dmSans(color: Colors.black54),
            prefixIcon: Icon(widget.icon, color: _primary),
            suffixIcon: _isLoading 
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16, height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    ),
                  ) 
                : widget.suffix,
            filled: true,
            fillColor: const Color(0xffFBFCFE),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primary, width: 1.4)),
          ),
          style: GoogleFonts.dmSans(fontSize: 15),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200, 
                maxWidth: MediaQuery.of(context).size.width - 36
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final dynamic option = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      option['display_name'] ?? '',
                      style: GoogleFonts.dmSans(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
